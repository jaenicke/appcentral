# C# (.NET)

AppCentral für C# besteht aus einer einzigen Datei `AppCentral.cs`. Diese wird
sowohl im Host als auch in Plugin-DLLs eingebunden.

Plugin-DLLs werden mit **NativeAOT** kompiliert - so entstehen echte native
Windows-DLLs ohne CLR-Initialisierungsanforderung beim Aufrufer. Hosts können
normales .NET sein.

Es gibt zwei Plugin-DLL-Varianten:

- **`CSharpDLL/`** - manuelle COM-Vtable in unsafe C# (verlässlich, aber mehr Code)
- **`CSharpDLLAuto/`** - deklarativ via `[GeneratedComInterface]` und
  `[GeneratedComClass]` (kürzer, aber mit einem Detail bei `QueryInterface`)

Beide funktionieren mit allen Hosts.

## Voraussetzungen

- .NET 8 SDK oder neuer (.NET 10 wird empfohlen, getestet).
- Visual Studio Build Tools (MSVC) für den NativeAOT-Linker.
- **`vswhere.exe` muss im PATH sein** - das Build-Skript ergänzt ihn aus
  `C:\Program Files (x86)\Microsoft Visual Studio\Installer\`.

## Einbindung in ein eigenes Projekt

### Host-Projekt

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
    <!-- AppCentral.cs als Link einbinden, nicht kopieren -->
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
        Console.WriteLine(example!.SayHello("Welt"));
        Console.WriteLine(example.Add(3, 4));
    }
}

TAppCentral.LoadPlugin("MyPlugin.dll");
RunExample();
TAppCentral.Shutdown();
```

### Plugin-Projekt (NativeAOT, deklarativ)

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
    public string SayHello(string name) => $"Hallo, {name}!";
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

        // CCW erstellen → liefert IUnknown*. Anschliessend QueryInterface
        // auf IAppCentralProvider, sonst hat der native Aufrufer die falsche
        // Vtable (kann u.a. IReferenceTrackerTarget treffen → Crash).
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

## Wichtige Regeln

### `IAppCentralProvider`-GUID muss matchen

`{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}` - identisch in allen Sprachen.

### `string` als BSTR marshallen

```csharp
[GeneratedComInterface(StringMarshalling = StringMarshalling.Custom,
    StringMarshallingCustomType = typeof(BStrStringMarshaller))]
```

Damit werden `string`-Parameter und `string`-Returns als BSTR marshalled,
kompatibel zu Delphis `WideString` (= BSTR im COM-Layer).

### NativeAOT-Falle: `GetOrCreateComInterfaceForObject` liefert IUnknown*

Wenn man die Rückgabe direkt an einen nativen Host (C++/Delphi/Rust/...)
weitergibt und der Slot 3 oder höher aufruft, kann er auf einer falschen
Vtable landen (z.B. `IReferenceTrackerTarget`). Das endet in einer
NullReferenceException oder einem Crash.

Lösung: nach `GetOrCreateComInterfaceForObject` ein explizites
`Marshal.QueryInterface(pUnk, in iid, out p)` aufrufen, um wirklich die
gewünschte Schnittstellen-Vtable zu bekommen. Das `RegisterHostImpl`-Beispiel
oben macht das.

### Host-Interface-Refs vor Shutdown freigeben

`TAppCentral.Get<T>` liefert ein normales .NET-Objekt mit COM-RCW dahinter. Die
RCW-Lebenszeit hängt am GC. **Bevor** `Shutdown()` die DLL entlädt, muss das
Interface raus aus dem Scope sein:

```csharp
void RunExample()
{
    if (TAppCentral.TryGet<IExample>(out var example))
        Console.WriteLine(example!.SayHello("Welt"));
}
// example ist nach RunExample weg

TAppCentral.LoadPlugin("foo.dll");
RunExample();
TAppCentral.Shutdown();  // ok
```

### NativeAOT-Voraussetzungen

- **`<PublishAot>true</PublishAot>`** und **`<NativeLib>Shared</NativeLib>`** in
  der DLL-csproj.
- `AllowUnsafeBlocks` für die `[UnmanagedCallersOnly]`-Methoden.
- Build via `dotnet publish -c Release -r win-x64`.

## Manuelle Vtable-Variante

Die `CSharpDLL/`-Variante umgeht ComWrappers vollständig und baut die
COM-Vtable manuell mit `delegate* unmanaged[Stdcall]<...>` und `NativeMemory.Alloc`
auf. Längerer Code, aber komplett unabhängig von .NET-Internals. Wenn ihr
plant, viele unterschiedliche Interfaces zu exportieren, ist die deklarative
Variante deutlich kürzer.

## API-Übersicht

```csharp
public static class TAppCentral
{
    // Registrierung
    public static void Register<T>(T instance) where T : class;
    public static void Register<T>(Func<object?, T> factory) where T : class;
    public static void Unregister<T>() where T : class;

    // Abfrage
    public static bool TryGet<T>(out T? result, object? parameters = null) where T : class;
    public static T Get<T>(object? parameters = null) where T : class;        // wirft AppCentralInterfaceNotFoundException
    public static List<T> GetAllPlugins<T>() where T : class;

    // Plugin-Verwaltung
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
Build\build_csharp.bat       (manuelle Variante)
Build\build_csharp_auto.bat  (deklarative Variante)
```

Erzeugt `Output/CSharpHost.exe`, `Output/ExampleCSharpDLL.dll` und
`Output/ExampleCSharpDLLAuto.dll`.
