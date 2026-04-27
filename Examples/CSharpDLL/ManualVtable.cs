using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Threading;

namespace AppCentralLib;

// ============================================================================
// ManualVtable - COM vtables built manually without ComWrappers
//
// Workaround for a NativeAOT limitation:
// StrategyBasedComWrappers exponiert IReferenceTrackerTarget im Vtable, was
// causes NullReferenceException when non-.NET hosts (C++/Delphi/Java)
// QueryInterface aufrufen.
//
// Here bauen wir die COM-Vtables manuell auf - genau wie der Java-DLL-C-Bridge.
// ============================================================================

internal static unsafe class ManualVtable
{
    // GUIDs
    public static readonly Guid IID_IUnknown = new("00000000-0000-0000-C000-000000000046");
    public static readonly Guid IID_IAppCentralProvider = new("F7E8D9C1-B1A2-4E3F-8071-926354AABBCC");
    public static readonly Guid IID_IExample = new("A1B2C3D4-E5F6-7890-ABCD-EF1234567890");

    // ========================================================================
    // Provider-Vtable (5 Eintraege: QI, AddRef, Release, GetInterface, Shutdown)
    // ========================================================================

    // Object layout: [vtable*][refCount][reserved for provider/example]
    [StructLayout(LayoutKind.Sequential)]
    public struct ComObject
    {
        public IntPtr Vtable;
        public int RefCount;
        public IntPtr Tag;  // Discriminator: 0 = Provider, 1 = Example
    }

    private static IntPtr s_ProviderVtable;
    private static IntPtr s_ExampleVtable;
    private static ComObject* s_LocalProvider;
    private static ComObject* s_ExampleObject;
    private static IntPtr s_HostProviderPtr;

    public static IntPtr GetLocalProviderPtr() => (IntPtr)s_LocalProvider;
    public static void SetHostProviderPtr(IntPtr ptr) { s_HostProviderPtr = ptr; }

    public static void Initialize()
    {
        // Provider Vtable: 5 Pointer
        s_ProviderVtable = (IntPtr)NativeMemory.Alloc(5 * (nuint)sizeof(IntPtr));
        var pv = (IntPtr*)s_ProviderVtable;
        pv[0] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, Guid*, IntPtr*, int>)&Provider_QueryInterface;
        pv[1] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, uint>)&Provider_AddRef;
        pv[2] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, uint>)&Provider_Release;
        pv[3] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, int, Guid*, IntPtr, IntPtr*, int>)&Provider_GetInterface;
        pv[4] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, int>)&Provider_Shutdown;

        // Example Vtable: 5 Pointer (QI/AddRef/Release/SayHello/Add)
        s_ExampleVtable = (IntPtr)NativeMemory.Alloc(5 * (nuint)sizeof(IntPtr));
        var ev = (IntPtr*)s_ExampleVtable;
        ev[0] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, Guid*, IntPtr*, int>)&Example_QueryInterface;
        ev[1] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, uint>)&Provider_AddRef;
        ev[2] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, uint>)&Example_Release;
        ev[3] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, IntPtr, IntPtr*, int>)&Example_SayHello;
        ev[4] = (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, int, int, int*, int>)&Example_Add;

        // Local Provider Singleton
        s_LocalProvider = (ComObject*)NativeMemory.Alloc((nuint)sizeof(ComObject));
        s_LocalProvider->Vtable = s_ProviderVtable;
        s_LocalProvider->RefCount = 1;
        s_LocalProvider->Tag = (IntPtr)0;

        // Example Singleton
        s_ExampleObject = (ComObject*)NativeMemory.Alloc((nuint)sizeof(ComObject));
        s_ExampleObject->Vtable = s_ExampleVtable;
        s_ExampleObject->RefCount = 1;
        s_ExampleObject->Tag = (IntPtr)1;
    }

    // ========================================================================
    // Provider-Methoden
    // ========================================================================

    // Interner Helper - direkt aufrufbar
    private static uint AddRefInternal(IntPtr pThis)
    {
        var obj = (ComObject*)pThis;
        return (uint)Interlocked.Increment(ref obj->RefCount);
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static int Provider_QueryInterface(IntPtr pThis, Guid* riid, IntPtr* ppv)
    {
        if (*riid == IID_IUnknown || *riid == IID_IAppCentralProvider)
        {
            *ppv = pThis;
            AddRefInternal(pThis);
            return 0; // S_OK
        }
        *ppv = IntPtr.Zero;
        return unchecked((int)0x80004002); // E_NOINTERFACE
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static uint Provider_AddRef(IntPtr pThis)
    {
        return AddRefInternal(pThis);
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static uint Provider_Release(IntPtr pThis)
    {
        var obj = (ComObject*)pThis;
        var n = (uint)Interlocked.Decrement(ref obj->RefCount);
        // Static singleton - don't free
        return n;
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static int Provider_GetInterface(IntPtr pThis, int fromHost, Guid* riid, IntPtr pParams, IntPtr* ppObj)
    {
        // fromHost isn't further evaluated here (the manual DLL knows
        // no loaded sub-plugins; it just has a local singleton).
        if (*riid == IID_IExample)
        {
            *ppObj = (IntPtr)s_ExampleObject;
            AddRefInternal(*ppObj);
            return 0;
        }
        *ppObj = IntPtr.Zero;
        return unchecked((int)0x80004002);
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static int Provider_Shutdown(IntPtr pThis)
    {
        TAppCentral.ReleaseHostProvider();
        return 0;
    }

    // ========================================================================
    // Example-Methoden (delegieren an C#-Implementierung)
    // ========================================================================

    private static readonly ExampleImpl s_ExampleImpl = new();

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static int Example_QueryInterface(IntPtr pThis, Guid* riid, IntPtr* ppv)
    {
        if (*riid == IID_IUnknown || *riid == IID_IExample)
        {
            *ppv = pThis;
            AddRefInternal(pThis);
            return 0;
        }
        *ppv = IntPtr.Zero;
        return unchecked((int)0x80004002);
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static uint Example_Release(IntPtr pThis)
    {
        // Singleton, nichts freigeben
        var obj = (ComObject*)pThis;
        return (uint)Interlocked.Decrement(ref obj->RefCount);
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static int Example_SayHello(IntPtr pThis, IntPtr name, IntPtr* result)
    {
        try
        {
            string nameStr = Marshal.PtrToStringBSTR(name) ?? "";
            string r = s_ExampleImpl.SayHello(nameStr);
            *result = Marshal.StringToBSTR(r);
            return 0;
        }
        catch
        {
            *result = IntPtr.Zero;
            return unchecked((int)0x80004005); // E_FAIL
        }
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvStdcall) })]
    private static int Example_Add(IntPtr pThis, int a, int b, int* result)
    {
        try
        {
            *result = s_ExampleImpl.Add(a, b);
            return 0;
        }
        catch
        {
            return unchecked((int)0x80004005);
        }
    }
}
