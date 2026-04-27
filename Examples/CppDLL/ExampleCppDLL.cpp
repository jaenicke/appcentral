/**
 * ExampleCppDLL - Sample DLL in C++
 * Registers IExample via AppCentral.
 *
 * Kompilieren (MSVC):
 *   cl /LD /EHsc /std:c++17 ExampleCppDLL.cpp ole32.lib oleaut32.lib /Fe:ExampleCppDLL.dll
 */

#include "../../AppCentral.h"
#include "../Interfaces.h"

#include <string>

// ============================================================================
// ExampleImpl - Implementiert IExample
// ============================================================================

class ExampleImpl : public IExample
{
    LONG m_refCount = 1;
    std::wstring m_greeting;

public:
    ExampleImpl(const std::wstring& greeting = L"Hello")
        : m_greeting(greeting) {}

    // IUnknown
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
        if (riid == IID_IUnknown || riid == __uuidof(IExample)) {
            *ppv = static_cast<IExample*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() override {
        return InterlockedIncrement(&m_refCount);
    }

    ULONG STDMETHODCALLTYPE Release() override {
        LONG ref = InterlockedDecrement(&m_refCount);
        if (ref == 0) delete this;
        return ref;
    }

    // IExample
    HRESULT STDMETHODCALLTYPE SayHello(BSTR name, BSTR* pResult) override {
        std::wstring result = m_greeting + L", " + name + L"! (from C++ DLL)";
        *pResult = SysAllocString(result.c_str());
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE Add(int a, int b, int* pResult) override {
        *pResult = a + b;
        return S_OK;
    }
};

// ============================================================================
// DLL Entry Point - Interface registrieren
// ============================================================================

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID lpReserved)
{
    if (reason == DLL_PROCESS_ATTACH) {
        CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        AppCentral::Register<IExample>(new ExampleImpl());
    }
    return TRUE;
}
