// AppCentral Rust host - loads a native AppCentral DLL and calls IExample.
// Shared protocol types and the load_plugin helper come from the `appcentral`
// library crate at the AppCentral root.

// COM identifiers (interfaces, methods) follow the COM/IDL convention of
// PascalCase rather than Rust's snake_case.
#![allow(non_snake_case, non_camel_case_types)]

use std::env;
use std::ffi::c_void;

use appcentral::{load_plugin, IAppCentralProvider, BOOL};
use windows::core::*;

// ============================================================================
// Sample interface (the host knows the GUID and vtable layout it wants)
// ============================================================================

#[interface("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
unsafe trait IExample: IUnknown {
    fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT;
    fn Add(&self, a: i32, b: i32, result: *mut i32) -> HRESULT;
}

unsafe fn try_get_example(provider: &IAppCentralProvider) -> Option<IExample> {
    let iid = IExample::IID;
    let mut obj_ptr: *mut c_void = std::ptr::null_mut();
    let hr = unsafe {
        provider.GetInterface(BOOL(1), &iid, std::ptr::null_mut(), &mut obj_ptr)
    };
    if hr.is_ok() && !obj_ptr.is_null() {
        Some(unsafe { IExample::from_raw(obj_ptr as *mut _) })
    } else {
        None
    }
}

fn main() -> Result<()> {
    println!("=== AppCentral Rust host ===");
    println!();

    let args: Vec<String> = env::args().collect();
    let dll_path = if args.len() > 1 {
        args[1].clone()
    } else {
        "ExampleRustDLL.dll".to_string()
    };

    println!("Loading {}...", dll_path);
    let provider = unsafe { load_plugin(&dll_path, std::ptr::null_mut())? };
    println!("Loaded.");

    let mut providers = vec![provider];
    let mut filenames = vec![dll_path.clone()];

    if args.len() > 2 {
        if let Ok(p2) = unsafe { load_plugin(&args[2], std::ptr::null_mut()) } {
            providers.push(p2);
            filenames.push(args[2].clone());
            println!("Second plugin loaded: {}", args[2]);
        }
    }

    println!();
    println!("--- Plugin list ---");
    for (i, fname) in filenames.iter().enumerate() {
        println!("  [{}] {}", i, fname);
    }
    println!();

    // TryGet from the first plugin
    if let Some(example) = unsafe { try_get_example(&providers[0]) } {
        let mut result = BSTR::default();
        let _ = unsafe { example.SayHello(BSTR::from("World"), &mut result) };
        println!("IExample.SayHello: {}", result);

        let mut sum: i32 = 0;
        let _ = unsafe { example.Add(3, 4, &mut sum) };
        println!("IExample.Add(3, 4): {}", sum);
    } else {
        println!("ERROR: IExample not found!");
    }

    println!();
    println!("Plugins offering IExample: {}", providers.len());
    for (i, p) in providers.iter().enumerate() {
        if let Some(ex) = unsafe { try_get_example(p) } {
            let mut result = BSTR::default();
            let _ = unsafe { ex.SayHello(BSTR::from("Plugin"), &mut result) };
            println!("  Plugin {}: {}", i, result);
        }
    }

    println!();
    println!("Shutdown...");
    for p in &providers {
        let _ = unsafe { p.Shutdown() };
    }
    drop(providers);
    println!("Done.");
    Ok(())
}
