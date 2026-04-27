# AppCentral

Ein leichtgewichtiges Plugin-System für Windows, das es erlaubt, Interfaces zwischen
Hostanwendungen und DLLs auszutauschen - sprachübergreifend. Eine Hostanwendung
in einer Sprache kann transparent Plugins benutzen, die in einer ganz anderen
Sprache geschrieben sind. Plugins können untereinander über den Host hinweg
kommunizieren.

Aktuell unterstützt:

| Sprache | Host | DLL/Plugin | Doku |
|---|:-:|:-:|---|
| C++ | ✅ | ✅ | [Doku/Cpp.md](Doku/Cpp.md) |
| C# (NativeAOT) | ✅ | ✅ | [Doku/CSharp.md](Doku/CSharp.md) |
| Delphi | ✅ | ✅ | [Doku/Delphi.md](Doku/Delphi.md) |
| F# | ✅ | – | [Doku/FSharp.md](Doku/FSharp.md) |
| FreePascal | ✅ | ✅ | [Doku/FreePascal.md](Doku/FreePascal.md) |
| Java | ✅ | ✅ | [Doku/Java.md](Doku/Java.md) |
| PowerShell | ✅ | – | [Doku/PowerShell.md](Doku/PowerShell.md) |
| Python | ✅ | – | [Doku/Python.md](Doku/Python.md) |
| Rust | ✅ | ✅ | [Doku/Rust.md](Doku/Rust.md) |
| VB.NET | ✅ | – | [Doku/VBNet.md](Doku/VBNet.md) |

70 Cross-Kombinationen aus diesen 10 Hosts und 7 DLL-Varianten sind getestet
([siehe Doku/Architektur.md](Doku/Architektur.md)).

## Was ist AppCentral?

Eine Hostanwendung lädt eine oder mehrere Plugin-DLLs. Plugins **registrieren**
COM-Interfaces (per GUID) bei einer zentralen Klasse `TAppCentral`. Der Host und
andere Plugins **fragen** Interfaces dort ab und benutzen sie - der Standort der
Implementierung ist transparent.

Die Kommunikation läuft auf der Ebene roher COM-Vtables und ist deshalb
unabhängig von der Sprache der jeweiligen Seite, solange beide Seiten die
gleichen Interface-Definitionen kennen (gleiche GUID, gleiches Layout).

## Beispiel-Interface

Alle Implementierungen verwenden dieses einfache Beispiel:

```pascal
IExample = interface(IUnknown)
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
  function SayHello(const Name: WideString): WideString; safecall;
  function Add(A, B: Integer): Integer; safecall;
end;
```

## Verwendung in fünf Zeilen

In Delphi:

```pascal
TAppCentral.LoadPlugin('Plugin.dll');
WriteLn(TAppCentral.Get<IExample>.SayHello('Welt'));
TAppCentral.Shutdown;
```

In C#:

```csharp
TAppCentral.LoadPlugin("Plugin.dll");
Console.WriteLine(TAppCentral.Get<IExample>().SayHello("Welt"));
TAppCentral.Shutdown();
```

In jeder anderen unterstützten Sprache analog. Details pro Sprache siehe
[Doku/](Doku/).

## API

`TAppCentral` (oder das jeweilige Sprach-Pendant) bietet:

| Funktion | Bedeutung |
|---|---|
| `Register<T>(instance)` | Interface lokal registrieren |
| `Unregister<T>` | Interface lokal entfernen |
| `Get<T>` | Interface holen, wirft Exception wenn nicht registriert |
| `TryGet<T>(out)` | Interface holen, liefert false statt Exception |
| `GetAllPlugins<T>` | Liefert das Interface aus **allen** Plugins die es anbieten |
| `LoadPlugin(filename)` | Plugin laden (Filename-Dedup) |
| `UnloadPlugin(filename)` | Plugin einzeln entladen |
| `PluginLoaded(filename)` | Prüfen ob Plugin geladen ist |
| `PluginCount`, `PluginFilename(i)` | Plugin-Liste enumerieren |
| `Shutdown` | Alle Plugins benachrichtigen, freigeben, entladen |

## Plugin-zu-Plugin-Kommunikation

Plugins können untereinander kommunizieren - der Host vermittelt:

```
  Plugin A ──┐
             ├── ruft Get<IExample> ──> Host ──> Plugin B (hat IExample registriert)
  Plugin B ──┘
```

Das funktioniert in beide Richtungen. Wichtig ist nur: jede Seite kennt das
Interface (GUID + Layout). Implementiert ist das mit einem `FromHost`-Flag in
`IAppCentralProvider.GetInterface`, das verhindert, dass eine vom Host
weitergeleitete Anfrage zurück zum Host läuft (Endlosschleife). Details in
[Doku/Architektur.md](Doku/Architektur.md).

## Architektur kompakt

- **`IAppCentralProvider`** ist die "infrastructure"-COM-Schnittstelle, über die
  sich Host und Plugins gegenseitig kennen lernen.
- Der DLL-Export `RegisterHost(hostProvider)` wird beim Laden vom Host aufgerufen
  und tauscht die Provider gegenseitig aus.
- Beim Marshalling werden auf der Boundary nur rohe `Pointer` verwendet, weil
  Delphis ABI bei Interface-Returns einen versteckten `out`-Parameter erzeugt
  und so mit C/C++/Rust-Hosts inkompatibel wäre.
- Das Provider-GUID ist `{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}`.

Mehr dazu in [Doku/Architektur.md](Doku/Architektur.md).

## Verzeichnisstruktur

```
AppCentral/
├── README.md
├── Doku/                           Detaillierte Dokumentation pro Sprache
├── Build/                          Build- und Test-Skripte
│   ├── build_all.bat               (baut alles, was geht)
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
│   ├── run_all_tests.cmd           (Cross-Test aller Kombinationen)
│   └── test_*.cmd                  (Einzeltests)
├── Output/                         Build-Ausgabe (.exe und .dll)
│
├── AppCentral.pas                  Delphi/FreePascal-Unit
├── AppCentral.h                    C++ Header (header-only)
├── AppCentral.cs                   C# Library (per File-Link von VB.NET/F#-Samples genutzt)
├── AppCentral.java                 Java-Host-Bibliothek (nutzt JNA)
├── AppCentral.ps1                  PowerShell-Host-Bibliothek (dot-source)
├── app_central.py                  Python-Host-Bibliothek (nutzt comtypes)
├── AppCentral.JNI.pas              Delphi-JNI-Bindings (für direkte
│                                   Java-Klassen-Nutzung ohne DLL)
├── AppCentralRust/                 Rust-Library-Crate (geteilt von RustHost+RustDLL)
│
└── Examples/                       Beispiel-Plugins, -Hosts und gemeinsame Beispiel-Interfaces
    ├── Interfaces.pas              Beispiel-Interfaces (Pascal-Seite)
    ├── Interfaces.h                Beispiel-Interfaces (C++-Seite)
    ├── Interfaces.cs               Beispiel-Interfaces (C#-Seite)
    │
    ├── CppDLL/                     C++ Beispiel-Plugin
    ├── CppHost/                    C++ Beispiel-Host
    ├── CSharpDLL/                  C# Plugin (manuelle COM-Vtable)
    ├── CSharpDLLAuto/              C# Plugin (deklarativ via [GeneratedComClass])
    ├── CSharpHost/                 C# Beispiel-Host
    ├── DelphiDLL/                  Delphi Beispiel-Plugin
    ├── DelphiHost/                 Delphi Beispiel-Host
    ├── DelphiJavaHost/             Delphi Host der direkt eine Java-Klasse
    │                               per JNI lädt (ohne DLL-Wrapper)
    ├── FreePascalDLL/              FreePascal Beispiel-Plugin
    ├── FreePascalHost/             FreePascal Beispiel-Host
    ├── FSharpHost/                 F# Beispiel-Host (mit lokaler AppCentralLib-Companion)
    ├── JavaDLL/                    Java Beispiel-Plugin (C-Bridge + Java)
    ├── JavaHost/                   Java Beispiel-Host (mit JNA)
    ├── PowerShellHost/             PowerShell-Sample-Host (nutzt Root-AppCentral.ps1)
    ├── PythonHost/                 Python Beispiel-Host (mit comtypes)
    ├── RustDLL/                    Rust Beispiel-Plugin
    ├── RustHost/                   Rust Beispiel-Host
    └── VBNetHost/                  VB.NET Beispiel-Host (mit lokaler AppCentralLib-Companion)
```

## Voraussetzungen

Komponenten werden nur gebaut, wenn ihre Toolchain vorhanden ist:

| Komponente | Toolchain |
|---|---|
| C++, Java DLL (C-Bridge) | Visual Studio (MSVC `cl.exe`) |
| Delphi | Embarcadero Delphi/RAD Studio (`dcc64.exe`) |
| C#, VB.NET, F# | .NET 10 SDK (`dotnet`) |
| Rust | Rust toolchain (`cargo`) |
| FreePascal | Lazarus 64-bit / Free Pascal Compiler 64-bit |
| Java | JDK 8+ (z. B. Eclipse Adoptium 25) |
| Python | Python 3 + `pip install comtypes` |

Die Build-Skripte sind alle x64. Architekturen müssen zwischen Host und DLL
übereinstimmen.

## AI Disclosure

Dieses Projekt wurde mit Unterstützung von [Claude](https://claude.ai) (Anthropic) weiterentwickelt. Architektur, Designentscheidungen, Anforderungen und Qualitätssicherung lagen beim menschlichen Autor. Die KI unterstützte mit Codeerzeugung und Dokumentation.

## License

This project is licensed under the [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/).
