# Rust

AppCentral für Rust verwendet das `windows`-Crate (offizielle Microsoft
Bindings). Mit den `#[interface]`- und `#[implement]`-Makros von windows-rs
werden COM-Vtables automatisch generiert, ähnlich zu C# `[GeneratedComInterface]`.

Der gemeinsame Protokoll-Code (`IAppCentralProvider`-Trait, `RegisterHostFn`-
Typ-Alias, Host-seitiger `load_plugin`-Helper) liegt in der Library-Crate
**`AppCentralRust/`** im AppCentral-Root. Sample-Host und Sample-DLL
referenzieren sie via Path-Dependency in ihrer `Cargo.toml` - die Protokoll-
Deklarationen werden so nicht dupliziert.

## Voraussetzungen

- Rust toolchain (stable). Empfohlen: Installation via `rustup`.
- Visual Studio Build Tools (MSVC) - der MSVC-Linker wird gebraucht.

## Einbindung in ein eigenes Projekt

`Cargo.toml`:

```toml
[package]
name = "MyPlugin"
version = "0.1.0"
edition = "2021"

[lib]
name = "MyPlugin"
crate-type = ["cdylib"]

[dependencies]
appcentral = { path = "../AppCentralRust" }
windows = { version = "0.59", features = [
    "Win32_Foundation",
    "Win32_System_Com",
    "Win32_System_Ole",
] }
windows-core = "0.59"
```

`src/lib.rs`:

```rust
use std::ffi::c_void;

// IAppCentralProvider, IAppCentralProvider_Impl, BOOL, S_OK, E_NOINTERFACE
// kommen alle aus dem geteilten appcentral-Crate.
use appcentral::{
    IAppCentralProvider, IAppCentralProvider_Impl,
    BOOL, S_OK, E_NOINTERFACE,
};
use windows::core::*;

// Sample-Interface bleibt im Projekt - nur das AppCentral-Protokoll wird
// via appcentral-Crate geteilt.
#[interface("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
unsafe trait IExample: IUnknown {
    fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT;
    fn Add(&self, a: i32, b: i32, result: *mut i32) -> HRESULT;
}

#[implement(IExample)]
struct ExampleImpl;

impl IExample_Impl for ExampleImpl_Impl {
    unsafe fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT {
        // Wichtig: name ist Caller-besessen. Drop würde SysFreeString aufrufen
        // → Double-Free → Crash. Daher mem::forget nach dem Auslesen.
        let name_str = name.to_string();
        std::mem::forget(name);

        let response = format!("Hallo, {}!", name_str);
        // ptr::write umgeht Drop am Zielort (uninitialisierter Speicher).
        unsafe { std::ptr::write(result, BSTR::from(response.as_str())); }
        S_OK
    }

    unsafe fn Add(&self, a: i32, b: i32, result: *mut i32) -> HRESULT {
        unsafe { *result = a + b; }
        S_OK
    }
}

#[implement(IAppCentralProvider)]
struct LocalProvider;

impl IAppCentralProvider_Impl for LocalProvider_Impl {
    unsafe fn GetInterface(
        &self, _from_host: BOOL, iid: *const GUID,
        _params: *mut c_void, out_obj: *mut *mut c_void,
    ) -> HRESULT {
        unsafe { *out_obj = std::ptr::null_mut(); }
        if unsafe { *iid } == IExample::IID {
            let example: IExample = ExampleImpl.into();
            unsafe { *out_obj = example.into_raw() as *mut c_void; }
            return S_OK;
        }
        E_NOINTERFACE
    }

    unsafe fn Shutdown(&self) -> HRESULT { S_OK }
}

#[no_mangle]
pub extern "system" fn RegisterHost(_host: *mut c_void) -> *mut c_void {
    let provider: IAppCentralProvider = LocalProvider.into();
    provider.into_raw() as *mut c_void
}
```

Build:

```
cargo build --release --target x86_64-pc-windows-msvc
```

Der Output ist `target/x86_64-pc-windows-msvc/release/MyPlugin.dll`.

## Beispiel - Host

```rust
use std::ffi::c_void;
use appcentral::{load_plugin, IAppCentralProvider, BOOL};
use windows::core::*;

#[interface("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
unsafe trait IExample: IUnknown {
    fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT;
    fn Add(&self, a: i32, b: i32, result: *mut i32) -> HRESULT;
}

fn main() -> Result<()> {
    // load_plugin ist der Host-seitige Helper aus dem appcentral-Crate.
    let provider = unsafe { load_plugin("MyPlugin.dll", std::ptr::null_mut())? };

    let iid = IExample::IID;
    let mut obj: *mut c_void = std::ptr::null_mut();
    unsafe { provider.GetInterface(BOOL(1), &iid, std::ptr::null_mut(), &mut obj) };
    let example: IExample = unsafe { IExample::from_raw(obj as _) };

    let mut result = BSTR::default();
    unsafe { example.SayHello(BSTR::from("Welt"), &mut result) };
    println!("{}", result);

    Ok(())
}
```

## Wichtige Regeln

### `BSTR`-Drop bei Inputs vermeiden

Rust's `BSTR::Drop` ruft `SysFreeString` auf. Wenn die COM-Methode einen
`name: BSTR` per-Wert bekommt und Rust ihn am Methoden-Ende droppt - während
der Caller diesen BSTR aber selbst noch besitzt - gibts Double-Free, Crash.

```rust
unsafe fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT {
    let s = name.to_string();
    std::mem::forget(name);  // ✓ Drop verhindern
    ...
}
```

### `*mut BSTR`-Output: `ptr::write`, nicht `*ptr =`

`*result = BSTR::from(...)` würde Drop auf den **alten** Wert von `*result`
aufrufen - aber das ist uninitialisierter Speicher. `ptr::write` schreibt ohne
Drop:

```rust
unsafe { std::ptr::write(result, BSTR::from(response.as_str())); }
```

### `extern "system"`, nicht `extern "stdcall"`

`extern "stdcall"` ist deprecated (zukünftig hard error). `extern "system"` ist
das korrekte Synonym, das auf Windows zu `__stdcall` (x86) bzw. zur normalen
x64-ABI mapped.

### Static state und `Send`/`Sync`

`IAppCentralProvider` enthält `NonNull<c_void>`, was nicht `Send` ist. Statische
Variablen vom Typ `Mutex<Option<IAppCentralProvider>>` gehen daher nicht
direkt. Workaround: in `RegisterHost` jedes Mal eine frische LocalProvider-
Instanz erzeugen (LocalProvider hat ohnehin keinen State).

### Architektur

Build standardmäßig auf x86_64 (`--target x86_64-pc-windows-msvc`). Mischen mit
x86 geht nicht.

## Build

```
Build\build_rust.bat
```

Lädt `vcvarsall.bat x64` und baut DLL und Host. Erzeugt
`Output/RustHost.exe` und `Output/ExampleRustDLL.dll`.

Erstmal-Build kann dauern (~3-5 Min) wegen `windows`-Crate-Compile. Folgebuilds
sind in Sekunden durch.
