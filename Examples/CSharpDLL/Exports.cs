using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace AppCentralLib;

// ============================================================================
// ExampleImpl - pure Java implementation (no COM markup)
// ============================================================================

public class ExampleImpl
{
    private readonly string _greeting;

    public ExampleImpl()
    {
        _greeting = "Hello";
    }

    public ExampleImpl(string greeting)
    {
        _greeting = greeting;
    }

    public string SayHello(string name)
    {
        return $"{_greeting}, {name}! (from C# DLL)";
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
    [UnmanagedCallersOnly(EntryPoint = "RegisterHost",
        CallConvs = new[] { typeof(CallConvStdcall) })]
    public static nint RegisterHost(nint hostProviderPtr)
    {
        // This manual variant can receive the host provider,
        // but doesn't call anything on it (no ComWrappers are used).
        // It only returns its own registered interfaces.
        ManualVtable.SetHostProviderPtr(hostProviderPtr);
        return ManualVtable.GetLocalProviderPtr();
    }

    [ModuleInitializer]
    public static void Initialize()
    {
        ManualVtable.Initialize();
    }
}
