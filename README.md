# AppCentral

A lightweight plugin system for Windows that lets host applications and DLLs
exchange interfaces — across languages. A host written in one language can
transparently use plugins written in a completely different language. Plugins
can also talk to each other through the host.

🇩🇪 [Deutsche Version](README.de.md)

Currently supported:

| Language | Host | DLL/Plugin | Documentation |
|---|:-:|:-:|---|
| C++ | ✅ | ✅ | [Docs/Cpp.md](Docs/Cpp.md) |
| C# (NativeAOT) | ✅ | ✅ | [Docs/CSharp.md](Docs/CSharp.md) |
| Delphi | ✅ | ✅ | [Docs/Delphi.md](Docs/Delphi.md) |
| F# | ✅ | – | [Docs/FSharp.md](Docs/FSharp.md) |
| FreePascal | ✅ | ✅ | [Docs/FreePascal.md](Docs/FreePascal.md) |
| Java | ✅ | ✅ | [Docs/Java.md](Docs/Java.md) |
| PowerShell | ✅ | – | [Docs/PowerShell.md](Docs/PowerShell.md) |
| Python | ✅ | – | [Docs/Python.md](Docs/Python.md) |
| Rust | ✅ | ✅ | [Docs/Rust.md](Docs/Rust.md) |
| VB.NET | ✅ | – | [Docs/VBNet.md](Docs/VBNet.md) |

70 cross-combinations of these 10 hosts and 7 DLL variants are tested
(see [Docs/Architecture.md](Docs/Architecture.md)).

## What is AppCentral?

A host application loads one or more plugin DLLs. Plugins **register** COM
interfaces (by GUID) with a central class `TAppCentral`. The host and other
plugins **query** that class for interfaces and use them — the location of the
implementation is transparent.

Communication happens at the level of raw COM vtables and is therefore
language-independent, as long as both sides know the same interface
definitions (same GUID, same layout).

## Sample interface

All implementations use this simple example:

```pascal
IExample = interface(IUnknown)
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
  function SayHello(const Name: WideString): WideString; safecall;
  function Add(A, B: Integer): Integer; safecall;
end;
```

## Five lines of usage

In Delphi:

```pascal
TAppCentral.LoadPlugin('Plugin.dll');
WriteLn(TAppCentral.Get<IExample>.SayHello('World'));
TAppCentral.Shutdown;
```

In C#:

```csharp
TAppCentral.LoadPlugin("Plugin.dll");
Console.WriteLine(TAppCentral.Get<IExample>().SayHello("World"));
TAppCentral.Shutdown();
```

The other supported languages work analogously. Per-language details in
[Docs/](Docs/).

## API

`TAppCentral` (or the equivalent in each language) provides:

| Function | Meaning |
|---|---|
| `Register<T>(instance)` | Register an interface locally |
| `Unregister<T>` | Remove an interface locally |
| `Get<T>` | Get an interface, throws if not registered |
| `TryGet<T>(out)` | Get an interface, returns false instead of throwing |
| `GetAllPlugins<T>` | Returns the interface from **all** plugins that offer it |
| `LoadPlugin(filename)` | Load a plugin (with filename de-duplication) |
| `UnloadPlugin(filename)` | Unload a single plugin |
| `PluginLoaded(filename)` | Check whether a plugin is loaded |
| `PluginCount`, `PluginFilename(i)` | Enumerate the plugin list |
| `Shutdown` | Notify all plugins, release them, unload them |

## Plugin-to-plugin communication

Plugins can talk to each other — the host acts as a router:

```
  Plugin A ──┐
             ├── calls Get<IExample> ──> Host ──> Plugin B (has IExample registered)
  Plugin B ──┘
```

This works in both directions. The only requirement is that each side knows
the interface (GUID + layout). Implemented via a `FromHost` flag in
`IAppCentralProvider.GetInterface`, which prevents a request that the host
forwarded from looping back to the host (infinite loop). Details in
[Docs/Architecture.md](Docs/Architecture.md).

## Architecture in brief

- **`IAppCentralProvider`** is the "infrastructure" COM interface that lets
  the host and plugins discover each other.
- The DLL export `RegisterHost(hostProvider)` is called by the host on load
  and exchanges the providers between the two sides.
- At the boundary, only raw `Pointer`s are used because Delphi's ABI generates
  a hidden `out` parameter for interface returns, which would be incompatible
  with C/C++/Rust hosts.
- The provider GUID is `{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}`.

More on this in [Docs/Architecture.md](Docs/Architecture.md).

## Directory layout

```
AppCentral/
├── README.md                       (English)
├── README.de.md                    (German)
├── Docs/                           Per-language documentation
│   ├── Architecture.md / .de.md
│   ├── Cpp.md / .de.md
│   ├── CSharp.md / .de.md
│   ├── Delphi.md / .de.md
│   └── ... (all languages)
├── Build/                          Build and test scripts
│   ├── build_all.bat               (builds whatever's available)
│   ├── build_cpp.bat
│   ├── build_csharp.bat
│   ├── build_csharp_auto.bat
│   ├── build_delphi.bat
│   ├── build_delphi_java.bat
│   ├── build_dotnet_hosts.bat      (VB.NET + F#)
│   ├── build_freepascal.bat
│   ├── build_java_dll.bat
│   ├── build_java_host.bat
│   ├── build_rust.bat
│   ├── run_all_tests.cmd           (cross-test of all combinations)
│   └── test_*.cmd                  (single-scenario tests)
├── Output/                         Build output (.exe and .dll)
│
├── AppCentral.pas                  Delphi/FreePascal unit
├── AppCentral.h                    C++ header (header-only)
├── AppCentral.cs                   C# library (file-linked by VB.NET/F# samples)
├── AppCentral.java                 Java host library (uses JNA)
├── AppCentral.ps1                  PowerShell host library (dot-source it)
├── app_central.py                  Python host library (uses comtypes)
├── AppCentral.JNI.pas              Delphi JNI bindings (for using Java
│                                   classes directly without a DLL wrapper)
├── AppCentralRust/                 Rust library crate (shared by RustHost+RustDLL)
│
└── Examples/                       Sample plugins, hosts and shared sample interfaces
    ├── Interfaces.pas              Sample interfaces (Pascal side)
    ├── Interfaces.h                Sample interfaces (C++ side)
    ├── Interfaces.cs               Sample interfaces (C# side)
    │
    ├── CppDLL/                     C++ sample plugin
    ├── CppHost/                    C++ sample host
    ├── CSharpDLL/                  C# plugin (manual COM vtable)
    ├── CSharpDLLAuto/              C# plugin (declarative via [GeneratedComClass])
    ├── CSharpHost/                 C# sample host
    ├── DelphiDLL/                  Delphi sample plugin
    ├── DelphiHost/                 Delphi sample host
    ├── DelphiJavaHost/             Delphi host that loads Java classes
    │                               directly via JNI (no DLL wrapper)
    ├── FreePascalDLL/              FreePascal sample plugin
    ├── FreePascalHost/             FreePascal sample host
    ├── FSharpHost/                 F# sample host (with local AppCentralLib companion)
    ├── JavaDLL/                    Java sample plugin (C bridge + Java)
    ├── JavaHost/                   Java sample host (with JNA)
    ├── PowerShellHost/             PowerShell sample host (uses root AppCentral.ps1)
    ├── PythonHost/                 Python sample host (with comtypes)
    ├── RustDLL/                    Rust sample plugin
    ├── RustHost/                   Rust sample host
    └── VBNetHost/                  VB.NET sample host (with local AppCentralLib companion)
```

## Requirements

Each component is only built if its toolchain is available:

| Component | Toolchain |
|---|---|
| C++, Java DLL (C bridge) | Visual Studio (MSVC `cl.exe`) |
| Delphi | Embarcadero Delphi/RAD Studio (`dcc64.exe`) |
| C#, VB.NET, F# | .NET 10 SDK (`dotnet`) |
| Rust | Rust toolchain (`cargo`) |
| FreePascal | Lazarus 64-bit / Free Pascal Compiler 64-bit |
| Java | JDK 8+ (e.g. Eclipse Adoptium 25) |
| Python | Python 3 + `pip install comtypes` |

The build scripts target x64. Architectures must match between host and DLL.

## AI Disclosure

This project was developed with the assistance of [Claude](https://claude.ai) (Anthropic). The architecture, design decisions, requirements, and quality assurance were provided by the human author. The AI assisted with code generation and documentation.

## License

This project is licensed under the [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/).
