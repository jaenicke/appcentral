/*
 * Copyright (c) 2026 Sebastian Jänicke (github.com/jaenicke)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace AppCentralLib;

// ============================================================================
// IAppCentralProvider - with FromHost flag (new GUID)
// ============================================================================

[GeneratedComInterface]
[Guid("F7E8D9C1-B1A2-4E3F-8071-926354AABBCC")]
public partial interface IAppCentralProvider
{
    [PreserveSig]
    int GetInterface([MarshalAs(UnmanagedType.Bool)] bool fromHost,
        in Guid iid, nint parameters, out nint obj);

    [PreserveSig]
    int Shutdown();
}

// ============================================================================
// Exception for Get<T>
// ============================================================================

public class AppCentralInterfaceNotFoundException : Exception
{
    public AppCentralInterfaceNotFoundException(Type t)
        : base($"AppCentral: interface \"{t.Name}\" not registered") { }
}

// ============================================================================
// Internal types
// ============================================================================

internal class RegistryEntry
{
    public object? Instance;
    public Func<object?, object>? Factory;
}

internal class PluginInfo
{
    public nint Handle;
    public IAppCentralProvider Provider = null!;
    public string Filename = "";
}

// ============================================================================
// TAppCentral - all features from the original (modernised)
// ============================================================================

public static class TAppCentral
{
    private static readonly Dictionary<Guid, RegistryEntry> _registry = new();
    private static readonly List<PluginInfo> _plugins = new();
    private static IAppCentralProvider? _hostProvider;
    private static readonly AppCentralLocalProvider _localProvider = new();

    internal static readonly StrategyBasedComWrappers ComWrappers = new();

    // ========================== Registration ==========================

    /// <summary>Register an interface with a singleton instance.</summary>
    public static void Register<T>(T instance) where T : class
    {
        _registry[typeof(T).GUID] = new RegistryEntry { Instance = instance };
    }

    /// <summary>Register an interface with a parameterless typed factory.
    /// Distinct method name (not a `Register` overload) - mirrors the
    /// Pascal side, where keeping `Register` non-overloaded sidesteps a
    /// generic-overload-resolution quirk in Delphi when the caller passes a
    /// class instance that still needs an implicit class-to-interface cast.
    /// Kept symmetric in C# for API consistency across the two languages.</summary>
    public static void RegisterProvider<T>(Func<T> provider) where T : class
    {
        _registry[typeof(T).GUID] = new RegistryEntry
        {
            // Inner lambda captures T from the outer generic scope, giving
            // a typed factory bridged to the untyped internal signature.
            Factory = _ => provider()!
        };
    }

    /// <summary>Register an interface with a typed factory taking a typed parameter.</summary>
    public static void RegisterProvider<TParam, T>(Func<TParam, T> provider)
        where TParam : class
        where T : class
    {
        _registry[typeof(T).GUID] = new RegistryEntry
        {
            // Inner lambda captures both TParam and T from the outer scope -
            // the boxed object? param gets cast back to TParam at call time.
            Factory = p => provider((TParam)p!)!
        };
    }

    public static void Unregister<T>() where T : class
    {
        _registry.Remove(typeof(T).GUID);
    }

    // ========================== Lookup ==========================

    /// <summary>Try to get the interface. Returns false if not found.</summary>
    public static bool TryGet<T>(out T? result) where T : class
    {
        var guid = typeof(T).GUID;
        if (ResolveInterface(false, guid, null, out var obj) && obj is T typed)
        {
            result = typed;
            return true;
        }
        result = null;
        return false;
    }

    /// <summary>TryGet with typed initialisation parameter.</summary>
    public static bool TryGet<TParam, T>(TParam parameters, out T? result)
        where TParam : class
        where T : class
    {
        var guid = typeof(T).GUID;
        if (ResolveInterface(false, guid, parameters, out var obj) && obj is T typed)
        {
            result = typed;
            return true;
        }
        result = null;
        return false;
    }

    /// <summary>Throws AppCentralInterfaceNotFoundException if not found.</summary>
    public static T Get<T>() where T : class
    {
        if (!TryGet<T>(out var result))
            throw new AppCentralInterfaceNotFoundException(typeof(T));
        return result!;
    }

    /// <summary>Get an interface, passing a typed initialisation parameter.</summary>
    public static T Get<TParam, T>(TParam parameters)
        where TParam : class
        where T : class
    {
        if (!TryGet<TParam, T>(parameters, out var result))
            throw new AppCentralInterfaceNotFoundException(typeof(T));
        return result!;
    }

    /// <summary>All plugins that offer the interface.</summary>
    public static List<T> GetAllPlugins<T>() where T : class
    {
        var result = new List<T>();
        var guid = typeof(T).GUID;
        foreach (var plugin in _plugins)
        {
            if (plugin.Provider.GetInterface(true, in guid, 0, out var objPtr) == 0 && objPtr != 0)
            {
                try
                {
                    var obj = ComWrappers.GetOrCreateObjectForComInstance(objPtr, CreateObjectFlags.None);
                    if (obj is T typed)
                        result.Add(typed);
                }
                finally
                {
                    Marshal.Release(objPtr);
                }
            }
        }
        return result;
    }

    // ========================== Plugin management ==========================

    public static bool LoadPlugin(string path)
    {
        if (PluginLoaded(path)) return true;

        var handle = NativeLibrary.Load(path);
        if (handle == 0) return false;

        if (!NativeLibrary.TryGetExport(handle, "RegisterHost", out var procAddr))
        {
            NativeLibrary.Free(handle);
            return false;
        }

        var localPtr = ComWrappers.GetOrCreateComInterfaceForObject(
            _localProvider, CreateComInterfaceFlags.None);

        // We need the IAppCentralProvider vtable, not IUnknown
        Guid providerIid = typeof(IAppCentralProvider).GUID;
        Marshal.QueryInterface(localPtr, in providerIid, out nint localProvPtr);
        Marshal.Release(localPtr);

        nint dllProviderPtr;
        unsafe
        {
            var registerHost = (delegate* unmanaged[Stdcall]<nint, nint>)procAddr;
            dllProviderPtr = registerHost(localProvPtr);
        }

        Marshal.Release(localProvPtr);

        if (dllProviderPtr == 0)
        {
            NativeLibrary.Free(handle);
            return false;
        }

        var dllProvider = (IAppCentralProvider)ComWrappers.GetOrCreateObjectForComInstance(
            dllProviderPtr, CreateObjectFlags.None);
        Marshal.Release(dllProviderPtr);

        _plugins.Add(new PluginInfo
        {
            Handle = handle,
            Provider = dllProvider,
            Filename = path
        });
        return true;
    }

    public static bool UnloadPlugin(string filename)
    {
        var name = Path.GetFileName(filename);
        for (int i = 0; i < _plugins.Count; i++)
        {
            if (string.Equals(Path.GetFileName(_plugins[i].Filename), name,
                StringComparison.OrdinalIgnoreCase))
            {
                try { _plugins[i].Provider.Shutdown(); } catch { }
                var handle = _plugins[i].Handle;
                _plugins.RemoveAt(i);
                if (handle != 0) NativeLibrary.Free(handle);
                return true;
            }
        }
        return false;
    }

    public static bool PluginLoaded(string filename)
    {
        var name = Path.GetFileName(filename);
        foreach (var p in _plugins)
        {
            if (string.Equals(Path.GetFileName(p.Filename), name,
                StringComparison.OrdinalIgnoreCase))
                return true;
        }
        return false;
    }

    public static int PluginCount => _plugins.Count;
    public static string PluginFilename(int idx) => _plugins[idx].Filename;

    public static void Shutdown()
    {
        foreach (var plugin in _plugins)
        {
            try { plugin.Provider.Shutdown(); } catch { }
        }
        var handles = new List<nint>();
        foreach (var plugin in _plugins) handles.Add(plugin.Handle);
        _plugins.Clear();
        foreach (var handle in handles)
        {
            if (handle != 0) NativeLibrary.Free(handle);
        }
    }

    // ========================== Internals ==========================

    public static IAppCentralProvider HandleRegisterHost(IAppCentralProvider? hostProvider)
    {
        _hostProvider = hostProvider;
        return _localProvider;
    }

    internal static void ReleaseHostProvider()
    {
        _hostProvider = null;
    }

    /// <summary>Routing logic - same as in Delphi/C++.</summary>
    internal static bool ResolveInterface(bool fromHost, Guid guid, object? parameters,
        out object? result)
    {
        result = null;

        // 1. Local registry
        if (_registry.TryGetValue(guid, out var entry))
        {
            result = entry.Factory != null ? entry.Factory(parameters) : entry.Instance;
            if (result != null) return true;
        }

        // 2. If not "from host" and host is known -> ask the host (with FromHost=false)
        if (!fromHost && _hostProvider != null)
        {
            nint paramPtr = ParamsToCom(parameters);
            try
            {
                if (_hostProvider.GetInterface(false, in guid, paramPtr, out var objPtr) == 0
                    && objPtr != 0)
                {
                    try
                    {
                        result = ComWrappers.GetOrCreateObjectForComInstance(objPtr, CreateObjectFlags.None);
                        if (result != null) return true;
                    }
                    finally { Marshal.Release(objPtr); }
                }
            }
            finally
            {
                if (paramPtr != 0) Marshal.Release(paramPtr);
            }
        }

        // 3. Ask plugins (FromHost=true so no plugin asks back)
        if (_plugins.Count > 0)
        {
            nint paramPtr = ParamsToCom(parameters);
            try
            {
                foreach (var plugin in _plugins)
                {
                    if (plugin.Provider.GetInterface(true, in guid, paramPtr, out var objPtr) == 0
                        && objPtr != 0)
                    {
                        try
                        {
                            result = ComWrappers.GetOrCreateObjectForComInstance(objPtr, CreateObjectFlags.None);
                            if (result != null) return true;
                        }
                        finally { Marshal.Release(objPtr); }
                    }
                }
            }
            finally
            {
                if (paramPtr != 0) Marshal.Release(paramPtr);
            }
        }

        return false;
    }

    private static nint ParamsToCom(object? parameters)
    {
        if (parameters == null) return 0;
        return ComWrappers.GetOrCreateComInterfaceForObject(parameters, CreateComInterfaceFlags.None);
    }

    /// <summary>Called by the COM provider to resolve (local + route via FromHost flag).</summary>
    internal static int ResolveLocalCom(bool fromHost, in Guid guid, nint parameters, out nint obj)
    {
        obj = 0;

        // 1. Local registry
        if (_registry.TryGetValue(guid, out var entry))
        {
            object? instance = entry.Factory != null
                ? entry.Factory(parameters != 0
                    ? ComWrappers.GetOrCreateObjectForComInstance(parameters, CreateObjectFlags.None)
                    : null)
                : entry.Instance;

            if (instance != null)
            {
                nint pUnk = ComWrappers.GetOrCreateComInterfaceForObject(instance,
                    CreateComInterfaceFlags.None);
                Guid localGuid = guid;
                int hr = Marshal.QueryInterface(pUnk, in localGuid, out obj);
                Marshal.Release(pUnk);
                if (hr == 0) return 0; // S_OK
            }
        }

        // 2. If not "from host" and host is known: forward
        if (!fromHost && _hostProvider != null)
        {
            int hr = _hostProvider.GetInterface(false, in guid, parameters, out obj);
            if (hr == 0) return 0;
        }

        // 3. Ask plugins (always with FromHost=true)
        foreach (var plugin in _plugins)
        {
            int hr = plugin.Provider.GetInterface(true, in guid, parameters, out obj);
            if (hr == 0) return 0;
        }

        return unchecked((int)0x80004002); // E_NOINTERFACE
    }
}

[GeneratedComClass]
internal partial class AppCentralLocalProvider : IAppCentralProvider
{
    public int GetInterface(bool fromHost, in Guid iid, nint parameters, out nint obj)
    {
        return TAppCentral.ResolveLocalCom(fromHost, in iid, parameters, out obj);
    }

    public int Shutdown()
    {
        TAppCentral.ReleaseHostProvider();
        return 0;
    }
}

// ============================================================================
// Helper for NativeAOT DLLs
// ============================================================================

public static class AppCentralExports
{
    public static nint RegisterHostImpl(nint hostProviderPtr)
    {
        var hostProvider = (IAppCentralProvider)TAppCentral.ComWrappers
            .GetOrCreateObjectForComInstance(hostProviderPtr, CreateObjectFlags.None);

        var localProvider = TAppCentral.HandleRegisterHost(hostProvider);

        // Create CCW and QI for IAppCentralProvider, otherwise the native
        // caller would get the wrong vtable.
        nint pUnk = TAppCentral.ComWrappers.GetOrCreateComInterfaceForObject(
            localProvider, CreateComInterfaceFlags.None);
        Guid iid = typeof(IAppCentralProvider).GUID;
        Marshal.QueryInterface(pUnk, in iid, out nint pProvider);
        Marshal.Release(pUnk);
        return pProvider;
    }
}
