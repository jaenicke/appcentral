// AppCentral Rust DLL - exports IExample via a COM vtable
//
// Uses the windows-rs crate. #[implement] generates the vtable + boilerplate.
// Shared protocol types (IAppCentralProvider, RegisterHost signature) come
// from the `appcentral` library crate at the AppCentral root.

// COM identifiers (interfaces, methods, the crate itself) follow the COM/IDL
// convention of PascalCase rather than Rust's snake_case.
#![allow(non_snake_case, non_camel_case_types)]

use std::ffi::c_void;

use appcentral::{
    IAppCentralProvider, IAppCentralProvider_Impl,
    BOOL, E_NOINTERFACE, S_OK,
};
use windows::core::*;

// ============================================================================
// Sample interface (lives with the example, not in the shared library)
// ============================================================================

#[interface("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
unsafe trait IExample: IUnknown {
    fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT;
    fn Add(&self, a: i32, b: i32, result: *mut i32) -> HRESULT;
}

// ============================================================================
// Implementations
// ============================================================================

#[implement(IExample)]
struct ExampleImpl {
    greeting: String,
}

impl IExample_Impl for ExampleImpl_Impl {
    unsafe fn SayHello(&self, name: BSTR, result: *mut BSTR) -> HRESULT {
        // Important: name is passed by value but the caller still owns
        // the BSTR. Without mem::forget, Rust's Drop would free it
        // (SysFreeString) -> the caller would later crash on free.
        let name_str = name.to_string();
        std::mem::forget(name);

        let response = format!("{}, {}! (from Rust DLL)", self.greeting, name_str);
        // ptr::write avoids Drop on the destination (uninitialised memory).
        unsafe { std::ptr::write(result, BSTR::from(response.as_str())); }
        S_OK
    }

    unsafe fn Add(&self, a: i32, b: i32, result: *mut i32) -> HRESULT {
        unsafe { *result = a + b; }
        S_OK
    }
}

#[implement(IAppCentralProvider)]
struct LocalProvider {}

impl IAppCentralProvider_Impl for LocalProvider_Impl {
    unsafe fn GetInterface(
        &self,
        _from_host: BOOL,
        iid: *const GUID,
        _params: *mut c_void,
        out_obj: *mut *mut c_void,
    ) -> HRESULT {
        let requested_iid = unsafe { *iid };
        unsafe { *out_obj = std::ptr::null_mut(); }

        if requested_iid == IExample::IID {
            let impl_obj = ExampleImpl { greeting: "Hello".to_string() };
            let example: IExample = impl_obj.into();
            // Hand over ownership - into_raw() consumes the smart pointer.
            unsafe { *out_obj = example.into_raw() as *mut c_void; }
            return S_OK;
        }

        E_NOINTERFACE
    }

    unsafe fn Shutdown(&self) -> HRESULT {
        S_OK
    }
}

// ============================================================================
// DLL export - static provider instance
// ============================================================================

// LocalProvider has no state - creating a fresh instance per RegisterHost call
// is trivial. This bypasses the Send/Sync wrapper for COM objects.

#[no_mangle]
pub extern "system" fn RegisterHost(
    _host_provider: *mut c_void,
) -> *mut c_void {
    let lp = LocalProvider {};
    let provider: IAppCentralProvider = lp.into();
    provider.into_raw() as *mut c_void
}
