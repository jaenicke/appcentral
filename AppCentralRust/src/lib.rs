// AppCentral Rust library - shared protocol code for hosts and DLLs.
//
// Both hosts and DLLs depend on this crate. Re-exports the windows-rs interface
// declarations for `IAppCentralProvider` plus a couple of helpers commonly
// needed by host code (load_plugin) so example projects don't have to vendor
// the same boilerplate.
//
// Sample interfaces (e.g. IExample) live in the example crates themselves -
// only the AppCentral protocol is shared here.

#![allow(non_snake_case, non_camel_case_types)]

use std::ffi::c_void;

pub use windows::core::*;
pub use windows::Win32::Foundation::{BOOL, E_FAIL, E_NOINTERFACE, S_OK};
pub use windows::Win32::System::LibraryLoader::{GetProcAddress, LoadLibraryW};

// ============================================================================
// IAppCentralProvider - the single protocol interface between hosts and DLLs
// ============================================================================

#[interface("F7E8D9C1-B1A2-4E3F-8071-926354AABBCC")]
pub unsafe trait IAppCentralProvider: IUnknown {
    pub fn GetInterface(
        &self,
        from_host: BOOL,
        iid: *const GUID,
        params: *mut c_void,
        out_obj: *mut *mut c_void,
    ) -> HRESULT;
    pub fn Shutdown(&self) -> HRESULT;
}

/// Function-pointer signature of the `RegisterHost` export every plugin DLL
/// must provide.
pub type RegisterHostFn = unsafe extern "system" fn(*mut c_void) -> *mut c_void;

// ============================================================================
// Host helper: load a plugin DLL, call its RegisterHost, return the provider
// ============================================================================

/// Load `path`, look up `RegisterHost`, call it with the host provider
/// pointer (or null if there is no host), and wrap the returned provider
/// pointer in a refcounted `IAppCentralProvider`.
///
/// # Safety
/// The DLL's RegisterHost is called as `unsafe extern "system"` and must
/// honour the AppCentral protocol (i.e. return a refcounted COM pointer
/// implementing IAppCentralProvider).
pub unsafe fn load_plugin(
    path: &str,
    host_provider: *mut c_void,
) -> Result<IAppCentralProvider> {
    let wide: Vec<u16> = path.encode_utf16().chain(std::iter::once(0)).collect();
    let h = unsafe { LoadLibraryW(PCWSTR(wide.as_ptr()))? };

    let proc = unsafe { GetProcAddress(h, s!("RegisterHost")) }
        .ok_or_else(Error::from_win32)?;
    let register: RegisterHostFn = unsafe { std::mem::transmute(proc) };

    let provider_ptr = unsafe { register(host_provider) };
    if provider_ptr.is_null() {
        return Err(Error::new(E_FAIL, "RegisterHost returned null"));
    }

    // from_raw takes ownership of the refcount returned by RegisterHost.
    Ok(unsafe { IAppCentralProvider::from_raw(provider_ptr as *mut _) })
}
