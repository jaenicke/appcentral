/**
 * Copyright (c) 2026 Sebastian Jänicke (github.com/jaenicke)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */
import com.sun.jna.*;
import com.sun.jna.platform.win32.*;
import com.sun.jna.ptr.*;
import com.sun.jna.win32.StdCallLibrary;

import java.io.File;
import java.util.*;

/**
 * AppCentral for Java - with FromHost routing, TryGet, GetAllPlugins, etc.
 * Uses JNA for COM interop with native DLLs.
 */
public class AppCentral {

    public static final Guid.GUID IID_PROVIDER =
        new Guid.GUID("{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}");

    private final List<PluginEntry> plugins = new ArrayList<>();
    private final Pointer localProviderPtr;
    private final LocalProviderCallbacks callbacks; // gegen GC schuetzen

    public AppCentral() {
        callbacks = new LocalProviderCallbacks();
        localProviderPtr = callbacks.comObject;
    }

    // =========================== Plugin management ===========================

    public boolean loadPlugin(String path) {
        if (pluginLoaded(path)) return true;

        NativeLibrary lib;
        try {
            lib = NativeLibrary.getInstance(path);
        } catch (UnsatisfiedLinkError e) {
            return false;
        }

        Function registerHost;
        try {
            registerHost = lib.getFunction("RegisterHost");
        } catch (UnsatisfiedLinkError e) {
            return false;
        }

        Pointer dllProviderPtr = (Pointer) registerHost.invoke(Pointer.class,
            new Object[]{localProviderPtr},
            Map.of(Library.OPTION_CALLING_CONVENTION, Function.ALT_CONVENTION));

        if (dllProviderPtr == null || Pointer.nativeValue(dllProviderPtr) == 0) {
            return false;
        }

        plugins.add(new PluginEntry(lib, dllProviderPtr, path));
        return true;
    }

    public boolean unloadPlugin(String filename) {
        String name = new File(filename).getName();
        for (Iterator<PluginEntry> it = plugins.iterator(); it.hasNext();) {
            PluginEntry e = it.next();
            if (new File(e.path).getName().equalsIgnoreCase(name)) {
                callShutdown(e.providerPtr);
                callRelease(e.providerPtr);
                it.remove();
                return true;
            }
        }
        return false;
    }

    public boolean pluginLoaded(String path) {
        String name = new File(path).getName();
        for (PluginEntry e : plugins) {
            if (new File(e.path).getName().equalsIgnoreCase(name))
                return true;
        }
        return false;
    }

    public int pluginCount() { return plugins.size(); }
    public String pluginFilename(int idx) { return plugins.get(idx).path; }

    public void shutdown() {
        for (PluginEntry e : plugins) {
            callShutdown(e.providerPtr);
            callRelease(e.providerPtr);
        }
        plugins.clear();
    }

    // ============================ Abfrage ============================

    /** TryGet pattern: returns null when not found. */
    public <T> T tryGet(Guid.GUID iid, java.util.function.Function<Pointer, T> factory) {
        return tryGet(iid, factory, null);
    }

    public <T> T tryGet(Guid.GUID iid, java.util.function.Function<Pointer, T> factory,
                        Pointer params) {
        // Ask plugins with FromHost=true (Java host has no local singletons here)
        for (PluginEntry e : plugins) {
            Pointer obj = callGetInterface(e.providerPtr, true, iid, params);
            if (obj != null) {
                return factory.apply(obj);
            }
        }
        return null;
    }

    /** Get pattern: throws an exception when not found. */
    public <T> T get(Guid.GUID iid, java.util.function.Function<Pointer, T> factory) {
        T result = tryGet(iid, factory, null);
        if (result == null)
            throw new RuntimeException("AppCentral: Interface " + iid + " not registered");
        return result;
    }

    /** All plugins that offer the interface. */
    public <T> List<T> getAllPlugins(Guid.GUID iid,
            java.util.function.Function<Pointer, T> factory) {
        List<T> result = new ArrayList<>();
        for (PluginEntry e : plugins) {
            Pointer obj = callGetInterface(e.providerPtr, true, iid, null);
            if (obj != null) {
                result.add(factory.apply(obj));
            }
        }
        return result;
    }

    // ============================ COM-Vtable-Aufrufe ============================
    // Vtable: [0]QI [1]AddRef [2]Release [3]GetInterface [4]Shutdown

    private static Pointer callGetInterface(Pointer comObj, boolean fromHost,
            Guid.GUID iid, Pointer params) {
        Pointer vtable = comObj.getPointer(0);
        long fnAddr = Pointer.nativeValue(vtable.getPointer(3L * Native.POINTER_SIZE));
        Function fn = Function.getFunction(new Pointer(fnAddr), Function.ALT_CONVENTION);

        Guid.GUID.ByReference iidRef = new Guid.GUID.ByReference(iid);
        PointerByReference ppObj = new PointerByReference();

        int hr = fn.invokeInt(new Object[]{comObj, fromHost ? 1 : 0,
            iidRef.getPointer(), params, ppObj});
        if (hr == 0 && ppObj.getValue() != null) {
            return ppObj.getValue();
        }
        return null;
    }

    private static void callShutdown(Pointer comObj) {
        try {
            Pointer vtable = comObj.getPointer(0);
            long fnAddr = Pointer.nativeValue(vtable.getPointer(4L * Native.POINTER_SIZE));
            Function fn = Function.getFunction(new Pointer(fnAddr), Function.ALT_CONVENTION);
            fn.invokeInt(new Object[]{comObj});
        } catch (Exception ignored) {
        }
    }

    private static void callRelease(Pointer comObj) {
        try {
            Pointer vtable = comObj.getPointer(0);
            long fnAddr = Pointer.nativeValue(vtable.getPointer(2L * Native.POINTER_SIZE));
            Function fn = Function.getFunction(new Pointer(fnAddr), Function.ALT_CONVENTION);
            fn.invokeInt(new Object[]{comObj});
        } catch (Exception ignored) {
        }
    }

    // ============================ LocalProvider ============================

    public interface QueryInterfaceCB extends StdCallLibrary.StdCallCallback {
        int callback(Pointer pThis, Pointer riid, PointerByReference ppv);
    }
    public interface RefCB extends StdCallLibrary.StdCallCallback {
        int callback(Pointer pThis);
    }
    public interface GetInterfaceCB extends StdCallLibrary.StdCallCallback {
        int callback(Pointer pThis, int fromHost, Pointer riid, Pointer params, PointerByReference ppObj);
    }

    private static class LocalProviderCallbacks {
        final QueryInterfaceCB queryInterface;
        final RefCB addRef;
        final RefCB release;
        final GetInterfaceCB getInterface;
        final RefCB shutdown;
        final Memory vtable;
        final Memory comObject;
        int refCount = 1;

        LocalProviderCallbacks() {
            queryInterface = (pThis, riid, ppv) -> {
                ppv.setValue(pThis);
                refCount++;
                return 0;
            };
            addRef = pThis -> ++refCount;
            release = pThis -> --refCount;
            getInterface = (pThis, fromHost, riid, params, ppObj) -> {
                // The Java host doesn't register interfaces locally
                ppObj.setValue(null);
                return 0x80004002; // E_NOINTERFACE
            };
            shutdown = pThis -> 0;

            vtable = new Memory(5L * Native.POINTER_SIZE);
            vtable.setPointer(0L * Native.POINTER_SIZE,
                CallbackReference.getFunctionPointer(queryInterface));
            vtable.setPointer(1L * Native.POINTER_SIZE,
                CallbackReference.getFunctionPointer(addRef));
            vtable.setPointer(2L * Native.POINTER_SIZE,
                CallbackReference.getFunctionPointer(release));
            vtable.setPointer(3L * Native.POINTER_SIZE,
                CallbackReference.getFunctionPointer(getInterface));
            vtable.setPointer(4L * Native.POINTER_SIZE,
                CallbackReference.getFunctionPointer(shutdown));

            comObject = new Memory(Native.POINTER_SIZE);
            comObject.setPointer(0, vtable);
        }
    }

    private static class PluginEntry {
        final NativeLibrary lib;
        final Pointer providerPtr;
        final String path;

        PluginEntry(NativeLibrary lib, Pointer providerPtr, String path) {
            this.lib = lib;
            this.providerPtr = providerPtr;
            this.path = path;
        }
    }
}
