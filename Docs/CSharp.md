# C# (.NET)

🇩🇪 [Deutsche Version](CSharp.de.md)

AppCentral for C# consists of a single file `AppCentral.cs`. It is included
both in hosts and in plugin DLLs.

Plugin DLLs are built with **NativeAOT** — that produces real native Windows
DLLs that don't require CLR initialization in the caller. Hosts can be normal
.NET.

There are two plugin DLL variants:

- **`CSharpDLL/`** — manual COM vtable in unsafe C# (reliable, but more code)
- **`CSharpDLLAuto/`** — declarative via `[GeneratedComInterface]` and
  `[GeneratedComClass]` (shorter, but with one detail around
  `QueryInterface`)

Both work with every host.

## Requirements

- .NET 8 SDK or newer (.NET 10 is recommended and tested).
- Visual Studio Build Tools (MSVC) for the NativeAOT linker.
- **`vswhere.exe` must be on PATH** — the build script adds it from
  `C:\Program Files (x86)\Microsoft Visual Studio\Installer\`.

## Adding it to your own project

### Host project

`MyHost.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
    <PlatformTarget>x64</PlatformTarget>
  </PropertyGroup>
  <ItemGroup>
    <!-- Include AppCentral.cs as a link, not a copy -->
    <Compile Include="..\AppCentral\AppCentral.cs" Link="AppCentral.cs" />
    <Compile Include="..\AppCentral\Interfaces.cs" Link="Interfaces.cs" />
  </ItemGroup>
</Project>
```

`Program.cs`:

```csharp
using AppCentralLib;

void RunExample()
{
    if (TAppCentral.TryGet<IExample>(out var example))
    {
        Console.WriteLine(example!.SayHello("World"));
        Console.WriteLine(example.Add(3, 4));
    }
}

TAppCentral.LoadPlugin("MyPlugin.dll");
RunExample();
TAppCentral.Shutdown();
```

### Plugin project (NativeAOT, declarative)

`MyPlugin.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
    <PublishAot>true</PublishAot>
    <IsAotCompatible>true</IsAotCompatible>
    <OutputType>Library</OutputType>
    <NativeLib>Shared</NativeLib>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="..\AppCentral\AppCentral.cs" Link="AppCentral.cs" />
  </ItemGroup>
</Project>
```

`Plugin.cs`:

```csharp
using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace AppCentralLib;

[GeneratedComInterface(StringMarshalling = StringMarshalling.Custom,
    StringMarshallingCustomType = typeof(BStrStringMarshaller))]
[Guid("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
public partial interface IExample
{
    string SayHello(string name);
    int Add(int a, int b);
}

[GeneratedComClass]
public partial class ExampleImpl : IExample
{
    public string SayHello(string name) => $"Hello, {name}!";
    public int Add(int a, int b) => a + b;
}

public static class NativeExports
{
    private static readonly StrategyBasedComWrappers _comWrappers = new();

    [UnmanagedCallersOnly(EntryPoint = "RegisterHost",
        CallConvs = new[] { typeof(CallConvStdcall) })]
    public static nint RegisterHost(nint hostProviderPtr)
    {
        IAppCentralProvider? hostProvider = null;
        if (hostProviderPtr != 0)
        {
            hostProvider = (IAppCentralProvider)_comWrappers
                .GetOrCreateObjectForComInstance(hostProviderPtr, CreateObjectFlags.None);
        }
        var localProvider = TAppCentral.HandleRegisterHost(hostProvider!);

        // Create CCW → returns IUnknown*. Then QueryInterface for
        // IAppCentralProvider, otherwise the native caller has the wrong
        // vtable (might hit IReferenceTrackerTarget → crash).
        nint pUnk = _comWrappers.GetOrCreateComInterfaceForObject(
            localProvider, CreateComInterfaceFlags.None);
        Guid iid = typeof(IAppCentralProvider).GUID;
        Marshal.QueryInterface(pUnk, in iid, out nint pProvider);
        Marshal.Release(pUnk);
        return pProvider;
    }

    [ModuleInitializer]
    public static void Initialize()
    {
        TAppCentral.Register<IExample>(new ExampleImpl());
    }
}
```

## Important rules

### `IAppCentralProvider` GUID must match

`{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}` — identical across every language.

### Marshal `string` as BSTR

```csharp
[GeneratedComInterface(StringMarshalling = StringMarshalling.Custom,
    StringMarshallingCustomType = typeof(BStrStringMarshaller))]
```

This marshals `string` parameters and returns as BSTR, compatible with
Delphi's `WideString` (= BSTR at the COM layer).

### NativeAOT pitfall: `GetOrCreateComInterfaceForObject` returns IUnknown*

If you hand the result directly to a native host (C++/Delphi/Rust/...) and it
calls slot 3 or higher, it might land on the wrong vtable (e.g.
`IReferenceTrackerTarget`). That ends with NullReferenceException or a crash.

Fix: after `GetOrCreateComInterfaceForObject`, call
`Marshal.QueryInterface(pUnk, in iid, out p)` explicitly to obtain the actual
target interface vtable. The `RegisterHostImpl` example above does this.

### Release host-side interface refs before Shutdown

`TAppCentral.Get<T>` returns a normal .NET object backed by a COM RCW. The
RCW's lifetime is tied to the GC. **Before** `Shutdown()` unloads the DLL the
interface must be out of scope:

```csharp
void RunExample()
{
    if (TAppCentral.TryGet<IExample>(out var example))
        Console.WriteLine(example!.SayHello("World"));
}
// example is gone after RunExample

TAppCentral.LoadPlugin("foo.dll");
RunExample();
TAppCentral.Shutdown();  // ok
```

### NativeAOT requirements

- **`<PublishAot>true</PublishAot>`** and **`<NativeLib>Shared</NativeLib>`**
  in the DLL csproj.
- `AllowUnsafeBlocks` for the `[UnmanagedCallersOnly]` methods.
- Build via `dotnet publish -c Release -r win-x64`.

## Manual vtable variant

The `CSharpDLL/` variant bypasses ComWrappers entirely and builds the COM
vtable manually using `delegate* unmanaged[Stdcall]<...>` and
`NativeMemory.Alloc`. More code, but completely independent of .NET internals.
If you plan to expose many different interfaces, the declarative variant is
much shorter.

## API summary

```csharp
public static class TAppCentral
{
    // Registration
    public static void Register<T>(T instance) where T : class;
    public static void Register<T>(Func<object?, T> factory) where T : class;
    public static void Unregister<T>() where T : class;

    // Lookup
    public static bool TryGet<T>(out T? result, object? parameters = null) where T : class;
    public static T Get<T>(object? parameters = null) where T : class;        // throws AppCentralInterfaceNotFoundException
    public static List<T> GetAllPlugins<T>() where T : class;

    // Plugin management
    public static bool LoadPlugin(string path);
    public static bool UnloadPlugin(string filename);
    public static bool PluginLoaded(string filename);
    public static int PluginCount { get; }
    public static string PluginFilename(int idx);
    public static void Shutdown();
}
```

## Build

```
Build\build_csharp.bat       (manual variant)
Build\build_csharp_auto.bat  (declarative variant)
```

Produces `Output/CSharpHost.exe`, `Output/ExampleCSharpDLL.dll`, and
`Output/ExampleCSharpDLLAuto.dll`.
