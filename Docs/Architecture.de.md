# Architektur

## Idee

Ein Host-Prozess lädt eine oder mehrere Plugin-DLLs. Beide Seiten kennen
COM-Interfaces (per GUID). Plugins **registrieren** Interface-Implementierungen
in einer zentralen Klasse `TAppCentral`, die Identische API in allen Sprachen
hat. Andere Komponenten **fragen** dieselbe Klasse nach Interfaces - egal ob
sie selbst Host oder Plugin sind, egal in welcher Sprache.

```
┌────────────────────┐       ┌──────────────────────┐
│   Hostanwendung    │       │     Plugin-DLL A     │
│                    │       │                      │
│  TAppCentral       │◄──────┤  TAppCentral         │
│  (lokale Registry, │       │  (lokale Registry,   │
│   FPlugins-Liste)  │       │   FHostProvider)     │
│                    │       │                      │
└────────┬───────────┘       └──────────────────────┘
         │
         │  IAppCentralProvider          ┌──────────────────────┐
         └──────────────────────────────►│     Plugin-DLL B     │
                                         │                      │
                                         │  TAppCentral ...     │
                                         └──────────────────────┘
```

## Bausteine

### `IAppCentralProvider`

Die Infrastruktur-Schnittstelle, über die sich Host und Plugins gegenseitig
kennen lernen. GUID `{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}`.

```pascal
IAppCentralProvider = interface(IUnknown)
  function GetInterface(FromHost: LongBool; const IID: TGUID;
    const Params: IInterface; out Obj: IUnknown): HResult; stdcall;
  function Shutdown: HResult; stdcall;
end;
```

- `GetInterface` ist die zentrale Such-Operation. Sie liefert ein Interface aus
  der lokalen Registry, falls vorhanden, sonst `E_NOINTERFACE`.
- `Shutdown` wird beim Entladen aufgerufen und gibt der DLL Gelegenheit, ihre
  Referenz auf den Host-Provider freizugeben.

### `TAppCentral`

Statische Klasse mit identischer API in allen Sprachen. Verwaltet:

- **Lokale Registry** - eine Map `GUID → Instanz` für Interfaces, die diese
  Komponente selbst registriert hat.
- **Plugin-Liste** (nur im Host) - geladene DLLs mit ihrem Provider.
- **Host-Provider** (nur in DLLs) - Provider-Referenz auf den Host.
- **Lokaler Provider** - die eigene Implementierung von `IAppCentralProvider`,
  die der Gegenseite über `RegisterHost` ausgehändigt wird.

### `RegisterHost(hostProvider) → localProvider`

Der DLL-Export, der beim Laden vom Host aufgerufen wird. Die DLL bekommt den
Host-Provider und gibt ihren eigenen Provider zurück. Damit können beide Seiten
sich gegenseitig nach Interfaces fragen.

Wichtig: Parameter und Return sind **rohe Pointer**, nicht typisierte
Interfaces. Mehr dazu unter "Refcounting" weiter unten.

## Routing - der `FromHost`-Flag

Was passiert, wenn Plugin A nach einem Interface fragt, das nur Plugin B
anbietet? Der Aufruf läuft über den Host:

```
Plugin A.Get<IFoo>
   ├─ lokale Registry: nicht da
   ├─ Host fragen (FromHost=False, "Du darfst weiterleiten")
   │     │
   │     ├─ Host's lokale Registry: nicht da
   │     ├─ Plugin A fragen (FromHost=True, "antworte nur lokal")
   │     │     └─ nicht da → E_NOINTERFACE
   │     └─ Plugin B fragen (FromHost=True)
   │           └─ ✓ gefunden, gib Interface zurück
   │
   └─ ✓ vom Host bekommen
```

Der `FromHost`-Flag verhindert, dass eine vom Host weitergeleitete Anfrage
zurück zum Host läuft (Endlosschleife). In jeder Sprache ist die
Routing-Logik gleich:

```
ResolveInterface(FromHost, IID, Params):
  1. Eigene Registry prüfen
  2. Wenn FromHost=False und HostProvider bekannt: HostProvider fragen
     (mit FromHost=False, damit der Host weiter routen darf)
  3. Geladene Plugins fragen (mit FromHost=True)
```

## Refcounting bei `RegisterHost(Pointer)`

Das ist die häufigste Verwirrung. Die Signatur ist:

```pascal
function RegisterHost(HostProvider: Pointer): Pointer; stdcall;
```

Warum `Pointer` statt `IAppCentralProvider`? Weil Delphi bei `stdcall`-Returns
managed Typen (Strings, Interfaces, dynamische Arrays) über einen
**versteckten `out`-Parameter** zurückgibt - Delphi-spezifisch und zu C/C++/Rust
inkompatibel. Plain `Pointer` wird in RAX zurückgegeben wie überall sonst auch.

Die Refcount-Konventionen sind dann manuell, analog zu COM:

| | Caller | Callee |
|---|---|---|
| **Parameter (`HostProvider: Pointer`)** | "geliehen" - kein AddRef beim Übergeben | kein Release beim Empfangen |
| **Return (`Pointer`)** | muss Release | muss AddRef vor Return |

Innerhalb einer Funktion gilt aber Delphis normale Auto-Refcounting-Regel:
sobald man einer **Interface-Variable** etwas zuweist, wird AddRef aufgerufen,
und beim Verlassen des Scopes Release.

```pascal
function RegisterHost(HostProvider: Pointer): Pointer; stdcall;
var
  LocalProv: IAppCentralProvider;       // Interface-Variable
begin
  LocalProv := TAppCentral.HandleRegisterHost(
    IAppCentralProvider(HostProvider)); // Hard-Cast, kein AddRef bei const-Param
  Result := Pointer(LocalProv);          // zurück als Pointer, kein AddRef
  if Result <> nil then
    IAppCentralProvider(Result)._AddRef; // expliziter AddRef für Caller
end;                                     // LocalProv geht out of scope -> Release
                                         // (hebt sich gegen den AddRef oben auf)
```

Auf der anderen Seite, im Host:

```pascal
RawResult := Proc(Pointer(FLocalProvider));     // Pointer-Cast: kein AddRef
DLLProvider := IAppCentralProvider(RawResult);  // Interface-Zuweisung: AddRef
IAppCentralProvider(RawResult)._Release;        // entfernt extra Ref vom Callee
```

Saldo: `DLLProvider` hält genau eine Referenz, alle Add/Release sind balanciert.

## Boundary-Issues, die unterwegs auftauchten

### `out BSTR` und Drop in Rust

`fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT` - wenn man
naiv `*result = BSTR::from(...)` schreibt, ruft Rust Drop auf den **alten**
Wert von `*result` auf - aber das ist uninitialisierter Speicher vom Host.
Heap-Korruption.

Fix: `std::ptr::write(result, BSTR::from(...))` schreibt ohne Drop des alten
Wertes.

### `name: BSTR` als Input-Parameter in Rust

Wenn die Methode endet, ruft Rust Drop auf `name` - was `SysFreeString` auf
einen Caller-besessenen BSTR aufruft. Double-Free.

Fix: `std::mem::forget(name)` nach dem Auslesen.

### NativeAOT und `IReferenceTrackerTarget`

`StrategyBasedComWrappers.GetOrCreateComInterfaceForObject` liefert einen
`IUnknown*` - dessen Vtable nach Slot 2 (Release) **nicht garantiert** zur
gewünschten Zielschnittstelle gehört (kann interne `IReferenceTrackerTarget`
sein). Native Aufrufer crashen dann beim Aufruf von Slot 3.

Fix: explizit `Marshal.QueryInterface(pUnk, in iid, out pProvider)` aufrufen,
um wirklich die Provider-Vtable zu bekommen.

### Delphi/Pascal Finalisierung mit Plugin-Records

`TList<TPluginInfo>.Clear` finalisiert nicht in jedem FPC-Build die
Interface-Felder eines Records korrekt. Daher in `Shutdown` die `Provider`
explizit auf `nil` setzen, bevor die Liste geleert wird.

### Java/JNA und Java 22+

Seit JDK 22 verlangt nativer Code-Zugriff `--enable-native-access=ALL-UNNAMED`,
sonst gibts eine Warnung (in einer kommenden Version: Fehler). Die generierten
`Build/run_java_host.cmd` enthält das Flag.

### FPC ohne `reference to function`

FPC 3.2.2 kennt keine Closure-Typen. Die Factory-Variante von `Register<T>` ist
in FPC ausgeklammert (`{$IFNDEF FPC}`).

### FPC Generic-Methoden, die andere Generics derselben Klasse aufrufen

`Get<T>` -> `TryGet<T>` -> Internal Compiler Error. Workaround: `Get<T>`
benutzt direkt `ResolveInterface` + `Supports` statt über `TryGet<T>`.

### x86 Name-Decoration

Auf x86 dekoriert `__stdcall` Exporte zu `_RegisterHost@4`. Die anderen Sprachen
suchen aber `RegisterHost`. Auf x86 wird im C++-Header per
`#pragma comment(linker, "/EXPORT:RegisterHost=_RegisterHost@4")` umbenannt.
Auf x64 dekoriert `__stdcall` nicht - Pragma wird per `#ifdef _M_IX86`
übersprungen.

## Test-Matrix

10 Hosts × 7 DLL-Varianten = 70 Cross-Kombinationen, alle getestet.
Skript: `Build/run_all_tests.cmd`.

| Host | Version |
|---|---|
| C++ | MSVC x64 |
| Delphi | RAD Studio Win64 |
| C# | .NET 10 |
| VB.NET | .NET 10 |
| F# | .NET 10 |
| Rust | Stable |
| FreePascal | 3.2.2 x64 (Lazarus 64-bit) |
| Java | JDK 25 + JNA 5.14 |
| Python | 3.x + comtypes 1.4 |
| PowerShell | Windows PowerShell 5.1 |

| DLL | Sprache |
|---|---|
| ExampleCppDLL.dll | C++ |
| ExampleDelphiDLL.dll | Delphi |
| ExampleFPCDLL.dll | FreePascal |
| ExampleRustDLL.dll | Rust |
| ExampleJavaDLL.dll | C-Bridge + Java (JNI, eingebettete JVM) |
| ExampleCSharpDLL.dll | C# NativeAOT (manuelle Vtable) |
| ExampleCSharpDLLAuto.dll | C# NativeAOT (deklarativ via `[GeneratedComClass]`) |

## Historie

Die Idee stammt von Sebastian Jänicke
([Original-Repo / Forum-Diskussion](https://en.delphipraxis.net/)). Sein
ursprüngliches AppCentral war Delphi+C# (mit dem alten NuGet-Paket
"UnmanagedExports") für x86. Diese Reimplementierung modernisiert das Konzept,
erweitert es auf 8 weitere Sprachen, baut auf x64 auf, ersetzt UnmanagedExports
durch NativeAOT-Exports, und ergänzt einen `FromHost`-Flag für sauberes
Plugin-zu-Plugin-Routing über den Host.
