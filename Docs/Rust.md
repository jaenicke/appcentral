# Rust

🇩🇪 [Deutsche Version](Rust.de.md)

AppCentral for Rust uses the `windows` crate (the official Microsoft bindings).
The `#[interface]` and `#[implement]` macros from windows-rs generate COM
vtables automatically, similar to C#'s `[GeneratedComInterface]`.

The shared protocol code (`IAppCentralProvider` trait, `RegisterHostFn`
type alias, host-side `load_plugin` helper) lives in the
**`AppCentralRust/`** library crate at the AppCentral root. Both the
sample host and the sample DLL depend on it via a path-dependency in
their `Cargo.toml`, so the protocol declarations aren't duplicated.

## Requirements

- Rust toolchain (stable). Recommended: install via `rustup`.
- Visual Studio Build Tools (MSVC) — the MSVC linker is required.

## Adding it to your own project

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
// all come from the shared appcentral crate.
use appcentral::{
    IAppCentralProvider, IAppCentralProvider_Impl,
    BOOL, S_OK, E_NOINTERFACE,
};
use windows::core::*;

// Sample interface stays with the project - only the AppCentral protocol
// is shared via the appcentral crate.
#[interface("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
unsafe trait IExample: IUnknown {
    fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT;
    fn Add(&self, a: i32, b: i32, result: *mut i32) -> HRESULT;
}

#[implement(IExample)]
struct ExampleImpl;

impl IExample_Impl for ExampleImpl_Impl {
    unsafe fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT {
        // Important: name is owned by the caller. Drop would call
        // SysFreeString → double-free → crash. So mem::forget after reading.
        let name_str = name.to_string();
        std::mem::forget(name);

        let response = format!("Hello, {}!", name_str);
        // ptr::write avoids dropping the destination (uninitialized memory).
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

The output is `target/x86_64-pc-windows-msvc/release/MyPlugin.dll`.

## Example — host

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
    // load_plugin is the host-side helper exposed by the appcentral crate.
    let provider = unsafe { load_plugin("MyPlugin.dll", std::ptr::null_mut())? };

    let iid = IExample::IID;
    let mut obj: *mut c_void = std::ptr::null_mut();
    unsafe { provider.GetInterface(BOOL(1), &iid, std::ptr::null_mut(), &mut obj) };
    let example: IExample = unsafe { IExample::from_raw(obj as _) };

    let mut result = BSTR::default();
    unsafe { example.SayHello(BSTR::from("World"), &mut result) };
    println!("{}", result);

    Ok(())
}
```

## Important rules

### Avoid BSTR Drop on inputs

Rust's `BSTR::Drop` calls `SysFreeString`. If a COM method receives
`name: BSTR` by value and Rust drops it at the end of the method — while the
caller still owns that BSTR — you get a double-free, crash.

```rust
unsafe fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT {
    let s = name.to_string();
    std::mem::forget(name);  // ✓ prevent Drop
    ...
}
```

### `*mut BSTR` output: use `ptr::write`, not `*ptr =`

`*result = BSTR::from(...)` would call Drop on the **old** value of `*result`
— but that's uninitialized memory. `ptr::write` writes without Drop:

```rust
unsafe { std::ptr::write(result, BSTR::from(response.as_str())); }
```

### `extern "system"`, not `extern "stdcall"`

`extern "stdcall"` is deprecated (will become a hard error). `extern "system"`
is the correct synonym, mapping to `__stdcall` on x86 and the regular x64 ABI
otherwise.

### Static state and `Send`/`Sync`

`IAppCentralProvider` contains `NonNull<c_void>`, which is not `Send`. Static
variables of type `Mutex<Option<IAppCentralProvider>>` therefore can't be
used directly. Workaround: in `RegisterHost` create a fresh LocalProvider each
time (LocalProvider has no state anyway).

### Architecture

The build defaults to x86_64 (`--target x86_64-pc-windows-msvc`). Mixing with
x86 will not work.

## Build

```
Build\build_rust.bat
```

Loads `vcvarsall.bat x64` and builds DLL and host. Produces
`Output/RustHost.exe` and `Output/ExampleRustDLL.dll`.

The first build can take a few minutes (~3–5 min) due to the `windows`-crate
compile time. Subsequent builds finish in seconds.
