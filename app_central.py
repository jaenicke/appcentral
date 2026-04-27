"""
 ************************************************************************
 * Copyright (c) 2026 Sebastian Jänicke (github.com/jaenicke)           *
 *                                                                      *
 * This Source Code Form is subject to the terms of the Mozilla Public  *
 * License, v. 2.0. If a copy of the MPL was not distributed with this  *
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.            *
 ************************************************************************

AppCentral for Python (modernised) - with FromHost routing, TryGet, GetAllPlugins, etc.

Voraussetzung: pip install comtypes
"""

import ctypes
import os
from ctypes import c_void_p, WinDLL

import comtypes
from comtypes import GUID, HRESULT, COMMETHOD, IUnknown, COMObject

# IAppCentralProvider with FromHost flag (new GUID)
class IAppCentralProvider(IUnknown):
    _iid_ = GUID('{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}')


IAppCentralProvider._methods_ = [
    COMMETHOD([], HRESULT, 'GetInterface',
              (['in'], ctypes.c_int32, 'fromHost'),
              (['in'], ctypes.POINTER(GUID), 'riid'),
              (['in'], ctypes.POINTER(IUnknown), 'pParams'),
              (['out'], ctypes.POINTER(ctypes.POINTER(IUnknown)), 'ppObj')),
    COMMETHOD([], HRESULT, 'Shutdown'),
]

E_NOINTERFACE = 0x80004002


class AppCentralInterfaceNotFound(RuntimeError):
    """Raised by Get<T> when the interface is not registered."""
    pass


class _LocalProvider(COMObject):
    _com_interfaces_ = [IAppCentralProvider]

    def __init__(self, registry):
        super().__init__()
        self._registry = registry

    def IAppCentralProvider_GetInterface(self, this, fromHost, riid, pParams, ppObj):
        """Called by the DLL when it needs an interface from the host."""
        # fromHost is not further evaluated here - the Python host has no local plugins
        if riid:
            guid_str = str(riid[0])
            if guid_str in self._registry:
                instance = self._registry[guid_str]
                ptr = instance._com_pointers_[IUnknown._iid_]
                instance.IUnknown_AddRef(this)
                ppObj[0] = ctypes.cast(ptr, ctypes.POINTER(IUnknown))
                return 0
        return E_NOINTERFACE

    def IAppCentralProvider_Shutdown(self, this):
        return 0


class AppCentral:
    """Modernised AppCentral API for Python."""

    def __init__(self):
        self._registry = {}
        self._plugins = []  # [(NativeLibrary, IAppCentralProvider, handle, filename)]
        self._local_provider = _LocalProvider(self._registry)

    # ========================== Registrierung ==========================

    def register(self, interface_class, instance):
        """Interface lokal registrieren."""
        guid_str = str(interface_class._iid_)
        self._registry[guid_str] = instance

    def unregister(self, interface_class):
        """Remove an interface from the local registry."""
        guid_str = str(interface_class._iid_)
        self._registry.pop(guid_str, None)

    # ========================== Plugin management ==========================

    def load_plugin(self, path):
        """Load a plugin. Already-loaded plugins aren't loaded again."""
        if self.plugin_loaded(path):
            return True

        handle = ctypes.windll.kernel32.LoadLibraryW(path)
        if not handle:
            return False

        try:
            dll = WinDLL(path)
        except OSError:
            ctypes.windll.kernel32.FreeLibrary(handle)
            return False

        register_host = dll.RegisterHost
        register_host.restype = c_void_p
        register_host.argtypes = [c_void_p]

        local_ptr = self._local_provider._com_pointers_[IAppCentralProvider._iid_]
        result_ptr = register_host(local_ptr)
        if not result_ptr:
            ctypes.windll.kernel32.FreeLibrary(handle)
            return False

        iunk = ctypes.cast(c_void_p(result_ptr), ctypes.POINTER(IUnknown))
        provider = iunk.QueryInterface(IAppCentralProvider)
        IUnknown.Release(iunk)

        self._plugins.append((dll, provider, handle, path))
        return True

    def unload_plugin(self, filename):
        name = os.path.basename(filename).lower()
        for i, entry in enumerate(self._plugins):
            if os.path.basename(entry[3]).lower() == name:
                try:
                    entry[1].Shutdown()
                except comtypes.COMError:
                    pass
                handle = entry[2]
                self._plugins.pop(i)
                if handle:
                    ctypes.windll.kernel32.FreeLibrary(handle)
                return True
        return False

    def plugin_loaded(self, path):
        name = os.path.basename(path).lower()
        return any(os.path.basename(p[3]).lower() == name for p in self._plugins)

    def plugin_count(self):
        return len(self._plugins)

    def plugin_filename(self, idx):
        return self._plugins[idx][3]

    # ========================== Abfrage ==========================

    def try_get(self, interface_class, params=None):
        """Get an interface. Returns None when not found."""
        iid = interface_class._iid_

        # Locale Registry zuerst
        guid_str = str(iid)
        if guid_str in self._registry:
            instance = self._registry[guid_str]
            ptr = instance._com_pointers_.get(IUnknown._iid_)
            if ptr:
                iunk = ctypes.cast(c_void_p(ptr), ctypes.POINTER(IUnknown))
                return iunk.QueryInterface(interface_class)

        # Ask plugins with FromHost=1
        params_ptr = self._params_to_com(params)
        for entry in self._plugins:
            try:
                obj = entry[1].GetInterface(1, iid, params_ptr)
                if obj:
                    return obj.QueryInterface(interface_class)
            except comtypes.COMError:
                continue
        return None

    def get(self, interface_class, params=None):
        """Throws AppCentralInterfaceNotFound when the interface is not found."""
        result = self.try_get(interface_class, params)
        if result is None:
            raise AppCentralInterfaceNotFound(
                f"AppCentral: Interface {interface_class.__name__} not registered")
        return result

    def get_all_plugins(self, interface_class):
        """List of all plugins that offer this interface."""
        result = []
        iid = interface_class._iid_
        for entry in self._plugins:
            try:
                obj = entry[1].GetInterface(1, iid, None)
                if obj:
                    result.append(obj.QueryInterface(interface_class))
            except comtypes.COMError:
                continue
        return result

    def shutdown(self):
        """Notify all plugins, release providers, unload DLLs."""
        handles = []
        while self._plugins:
            entry = self._plugins.pop()
            handles.append(entry[2])
            try:
                entry[1].Shutdown()
            except comtypes.COMError:
                pass
            del entry

        import gc
        gc.collect()

        for handle in handles:
            if handle:
                ctypes.windll.kernel32.FreeLibrary(handle)

    # ========================== Internals ==========================

    @staticmethod
    def _params_to_com(params):
        if params is None:
            return None
        return ctypes.cast(
            c_void_p(params._com_pointers_[IUnknown._iid_]),
            ctypes.POINTER(IUnknown))
