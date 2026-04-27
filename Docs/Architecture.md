# Architecture

🇩🇪 [Deutsche Version](Architecture.de.md)

## Concept

A host process loads one or more plugin DLLs. Both sides know COM interfaces
(by GUID). Plugins **register** interface implementations with a central class
`TAppCentral`, which has an identical API in every language. Other components
**query** that same class for interfaces — regardless of whether they are
hosts or plugins themselves, regardless of language.

```
┌────────────────────┐       ┌──────────────────────┐
│   Host application │       │     Plugin DLL A     │
│                    │       │                      │
│  TAppCentral       │◄──────┤  TAppCentral         │
│  (local registry,  │       │  (local registry,    │
│   plugin list)     │       │   host provider)     │
│                    │       │                      │
└────────┬───────────┘       └──────────────────────┘
         │
         │  IAppCentralProvider          ┌──────────────────────┐
         └──────────────────────────────►│     Plugin DLL B     │
                                         │                      │
                                         │  TAppCentral ...     │
                                         └──────────────────────┘
```

## Building blocks

### `IAppCentralProvider`

The infrastructure interface used by the host and plugins to discover each
other. GUID `{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}`.

```pascal
IAppCentralProvider = interface(IUnknown)
  function GetInterface(FromHost: LongBool; const IID: TGUID;
    const Params: IInterface; out Obj: IUnknown): HResult; stdcall;
  function Shutdown: HResult; stdcall;
end;
```

- `GetInterface` is the central lookup operation. It returns an interface from
  the local registry if available, otherwise `E_NOINTERFACE`.
- `Shutdown` is called when the plugin is being unloaded and gives the DLL a
  chance to release its reference to the host provider.

### `TAppCentral`

A static class with an identical API across all languages. It manages:

- **Local registry** — a `GUID → instance` map for interfaces that this
  component itself registered.
- **Plugin list** (host only) — loaded DLLs and their providers.
- **Host provider** (plugins only) — the provider reference back to the host.
- **Local provider** — this component's own implementation of
  `IAppCentralProvider`, handed to the other side via `RegisterHost`.

### `RegisterHost(hostProvider) → localProvider`

The DLL export that the host calls when loading the DLL. The DLL receives the
host's provider and returns its own. This way both sides can ask each other
for interfaces.

Important: parameter and return are **raw pointers**, not typed interfaces.
See "Reference counting" below.

## Routing — the `FromHost` flag

What happens when plugin A asks for an interface that only plugin B provides?
The call goes through the host:

```
Plugin A.Get<IFoo>
   ├─ local registry: not here
   ├─ ask host (FromHost=False, "you may forward")
   │     │
   │     ├─ host's local registry: not here
   │     ├─ ask plugin A (FromHost=True, "answer locally only")
   │     │     └─ not here → E_NOINTERFACE
   │     └─ ask plugin B (FromHost=True)
   │           └─ ✓ found, return interface
   │
   └─ ✓ got it from the host
```

The `FromHost` flag prevents a request that the host forwarded from looping
back to the host (infinite loop). The routing logic is identical in every
language:

```
ResolveInterface(FromHost, IID, Params):
  1. Check own registry
  2. If FromHost=False and HostProvider known: ask HostProvider
     (with FromHost=False so the host can keep routing)
  3. Ask loaded plugins (with FromHost=True)
```

## Reference counting through `RegisterHost(Pointer)`

This is the most common point of confusion. The signature is:

```pascal
function RegisterHost(HostProvider: Pointer): Pointer; stdcall;
```

Why `Pointer` instead of `IAppCentralProvider`? Because Delphi returns managed
types (strings, interfaces, dynamic arrays) from `stdcall` functions through
a **hidden `out` parameter** — this is Delphi-specific and incompatible with
C/C++/Rust. Plain `Pointer` is returned in RAX like any other pointer.

The reference-counting conventions are then manual, analogous to COM:

| | Caller | Callee |
|---|---|---|
| **Parameter (`HostProvider: Pointer`)** | "borrowed" — no AddRef on the call boundary | no Release on receive |
| **Return (`Pointer`)** | must Release | must AddRef before return |

Inside a function Delphi's normal automatic reference counting still applies:
as soon as you assign to an **interface variable**, AddRef is called, and on
scope exit Release.

```pascal
function RegisterHost(HostProvider: Pointer): Pointer; stdcall;
var
  LocalProv: IAppCentralProvider;       // interface variable
begin
  LocalProv := TAppCentral.HandleRegisterHost(
    IAppCentralProvider(HostProvider)); // hard cast, no AddRef on const param
  Result := Pointer(LocalProv);          // back to a pointer, no AddRef
  if Result <> nil then
    IAppCentralProvider(Result)._AddRef; // explicit AddRef for the caller
end;                                     // LocalProv goes out of scope -> Release
                                         // (cancels the AddRef above)
```

On the other side, in the host:

```pascal
RawResult := Proc(Pointer(FLocalProvider));     // pointer cast: no AddRef
DLLProvider := IAppCentralProvider(RawResult);  // interface assignment: AddRef
IAppCentralProvider(RawResult)._Release;        // remove the extra ref from the callee
```

Net effect: `DLLProvider` holds exactly one reference, every Add/Release is
balanced.

## Boundary issues encountered along the way

### `out BSTR` and Drop in Rust

`fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT` — naively
writing `*result = BSTR::from(...)` calls Drop on the **old** value of
`*result` — but that's uninitialized memory from the host. Heap corruption.

Fix: `std::ptr::write(result, BSTR::from(...))` writes without dropping the
old value.

### `name: BSTR` as input parameter in Rust

When the method ends, Rust calls Drop on `name` — which calls `SysFreeString`
on a caller-owned BSTR. Double free.

Fix: `std::mem::forget(name)` after reading it.

### NativeAOT and `IReferenceTrackerTarget`

`StrategyBasedComWrappers.GetOrCreateComInterfaceForObject` returns an
`IUnknown*` whose vtable from slot 2 (Release) **isn't guaranteed** to belong
to the desired target interface (it could be the runtime's
`IReferenceTrackerTarget` instead). Native callers crash when calling slot 3.

Fix: explicitly call `Marshal.QueryInterface(pUnk, in iid, out pProvider)` to
get the actual provider vtable.

### Delphi/Pascal finalization with plugin records

`TList<TPluginInfo>.Clear` does not always finalize the interface fields of a
record correctly in every FPC build. So in `Shutdown`, set `Provider` to `nil`
explicitly before clearing the list.

### Java/JNA and Java 22+

Since JDK 22, native code access requires `--enable-native-access=ALL-UNNAMED`,
otherwise you get a warning (and an error in a future version). The generated
`Build/run_java_host.cmd` includes that flag.

### FPC without `reference to function`

FPC 3.2.2 has no closure types. The factory variant of `Register<T>` is
disabled in FPC (`{$IFNDEF FPC}`).

### FPC generic methods calling other generics of the same class

`Get<T>` -> `TryGet<T>` -> internal compiler error. Workaround: `Get<T>` calls
`ResolveInterface` + `Supports` directly instead of going through `TryGet<T>`.

### x86 name decoration

On x86, `__stdcall` decorates exports as `_RegisterHost@4`. The other languages
look for `RegisterHost`. On x86 the C++ header uses
`#pragma comment(linker, "/EXPORT:RegisterHost=_RegisterHost@4")` to rename it.
On x64 `__stdcall` doesn't decorate — the pragma is skipped via `#ifdef _M_IX86`.

## Test matrix

10 hosts × 7 DLL variants = 70 cross-combinations, all tested.
Script: `Build/run_all_tests.cmd`.

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

| DLL | Language |
|---|---|
| ExampleCppDLL.dll | C++ |
| ExampleDelphiDLL.dll | Delphi |
| ExampleFPCDLL.dll | FreePascal |
| ExampleRustDLL.dll | Rust |
| ExampleJavaDLL.dll | C bridge + Java (JNI, embedded JVM) |
| ExampleCSharpDLL.dll | C# NativeAOT (manual vtable) |
| ExampleCSharpDLLAuto.dll | C# NativeAOT (declarative via `[GeneratedComClass]`) |

## History

The idea comes from Sebastian Jänicke
([original repo / forum thread](https://en.delphipraxis.net/)). His original
AppCentral was Delphi+C# (using the old NuGet package "UnmanagedExports") for
x86. This re-implementation modernizes the concept, extends it to 8 more
languages, builds for x64, replaces UnmanagedExports with NativeAOT exports,
and adds a `FromHost` flag for clean plugin-to-plugin routing through the host.
