/**
 * Interfaces.h - sample interfaces (counterpart to Interfaces.pas).
 * Shared between hosts and DLLs.
 */

#pragma once

#include <unknwn.h>
#include <oleauto.h>

// ============================================================================
// IExample - safecall in Delphi = HRESULT + retval in COM
// ============================================================================

// {A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
MIDL_INTERFACE("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
IExample : public IUnknown
{
    virtual HRESULT STDMETHODCALLTYPE SayHello(BSTR name, BSTR* pResult) = 0;
    virtual HRESULT STDMETHODCALLTYPE Add(int a, int b, int* pResult) = 0;
};

// ============================================================================
// IExampleParams - optional parameter interface
// ============================================================================

// {B2C3D4E5-F6A7-8901-BCDE-F12345678901}
MIDL_INTERFACE("B2C3D4E5-F6A7-8901-BCDE-F12345678901")
IExampleParams : public IUnknown
{
    virtual HRESULT STDMETHODCALLTYPE GetGreeting(BSTR* pResult) = 0;
};
