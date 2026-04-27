using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace AppCentralLib;

// ============================================================================
// ExampleImpl - declarative COM class via [GeneratedComClass]
// ============================================================================

[GeneratedComClass]
public partial class ExampleImpl : IExample
{
    private readonly string _greeting;

    public ExampleImpl()
    {
        _greeting = "Hello";
    }

    public string SayHello(string name)
    {
        return $"{_greeting}, {name}! (from C# DLL Auto)";
    }

    public int Add(int a, int b)
    {
        return a + b;
    }
}

// ============================================================================
// DLL-Exports
// ============================================================================

public static class NativeExports
{
    private static readonly StrategyBasedComWrappers _comWrappers = new();

    [UnmanagedCallersOnly(EntryPoint = "RegisterHost",
        CallConvs = new[] { typeof(CallConvStdcall) })]
    public static nint RegisterHost(nint hostProviderPtr)
    {
        // The host provider may be null (e.g. the Rust host doesn't pass one).
        IAppCentralProvider? hostProvider = null;
        if (hostProviderPtr != 0)
        {
            hostProvider = (IAppCentralProvider)_comWrappers
                .GetOrCreateObjectForComInstance(hostProviderPtr, CreateObjectFlags.None);
        }

        var localProvider = TAppCentral.HandleRegisterHost(hostProvider!);

        // Create CCW - returns IUnknown*
        nint pUnk = _comWrappers.GetOrCreateComInterfaceForObject(
            localProvider, CreateComInterfaceFlags.None);

        // IMPORTANT: explicitly call QueryInterface for IAppCentralProvider,
        // so the caller actually gets the provider vtable instead of
        // die generische IUnknown-Vtable (die intern auf IReferenceTrackerTarget
        // zeigen kann -> Crash bei nativem Zugriff).
        Guid iid = typeof(IAppCentralProvider).GUID;
        int hr = Marshal.QueryInterface(pUnk, in iid, out nint pProvider);
        Marshal.Release(pUnk);

        if (hr != 0)
        {
            throw new InvalidOperationException(
                $"QueryInterface for IAppCentralProvider failed: 0x{hr:X8}");
        }

        return pProvider;
    }

    [ModuleInitializer]
    public static void Initialize()
    {
        TAppCentral.Register<IExample>(new ExampleImpl());
    }
}
