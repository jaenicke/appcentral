# C++

🇩🇪 [Deutsche Version](Cpp.de.md)

AppCentral for C++ is **header-only**. A single file `AppCentral.h` contains
all implementations (using C++17 `inline` variables for the static fields)
and is included in both hosts and DLLs.

## Requirements

- Visual Studio 2019+ (MSVC, x64).
- C++17 or newer.

## Adding it to your own project

1. Put **`AppCentral.h`** in the include path.
2. Add **`Interfaces.h`** for the interface declarations.
3. In the host: `#include "AppCentral.h"` is enough.
4. In a DLL: `#include "AppCentral.h"` is enough. `RegisterHost` is exported
   automatically via `__declspec(dllexport)`.
5. When linking: `ole32.lib` and `oleaut32.lib` for COM/BSTR.

## Example — DLL

```cpp
// MyPlugin.cpp
#include "AppCentral.h"
#include "Interfaces.h"

#include <string>

class ExampleImpl : public IExample
{
    LONG m_refCount = 1;
public:
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

    HRESULT STDMETHODCALLTYPE SayHello(BSTR name, BSTR* pResult) override {
        std::wstring r = std::wstring(L"Hello, ") + name + L"!";
        *pResult = SysAllocString(r.c_str());
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE Add(int a, int b, int* pResult) override {
        *pResult = a + b;
        return S_OK;
    }
};

BOOL APIENTRY DllMain(HMODULE, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        AppCentral::Register<IExample>(new ExampleImpl());
    }
    return TRUE;
}
```

Compile as DLL:

```
cl /LD /EHsc /std:c++17 MyPlugin.cpp ole32.lib oleaut32.lib /Fe:MyPlugin.dll
```

## Example — host

```cpp
#include "AppCentral.h"
#include "Interfaces.h"
#include <cstdio>

int wmain(int argc, wchar_t* argv[])
{
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    AppCentral::LoadPlugin(L"MyPlugin.dll");

    {
        // ComPtr in an inner scope — automatic Release at block exit
        Microsoft::WRL::ComPtr<IExample> example;
        AppCentral::TryGet<IExample>(example);

        BSTR result = nullptr;
        example->SayHello(SysAllocString(L"World"), &result);
        wprintf(L"%s\n", result);
        SysFreeString(result);
    }
    // ComPtr already called Release here

    AppCentral::Shutdown();
    CoUninitialize();
    return 0;
}
```

## Important rules

### Interfaces as pure vtable classes with `MIDL_INTERFACE`

```cpp
MIDL_INTERFACE("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
IExample : public IUnknown
{
    virtual HRESULT STDMETHODCALLTYPE SayHello(BSTR name, BSTR* pResult) = 0;
    virtual HRESULT STDMETHODCALLTYPE Add(int a, int b, int* pResult) = 0;
};
```

`MIDL_INTERFACE("...")` is the MSVC idiom for `__declspec(uuid("..."))` — this
makes `__uuidof(IExample)` work at compile time. Methods must be pure virtual
and `STDMETHODCALLTYPE` (= `__stdcall`).

The signatures correspond to Delphi's `safecall` at the vtable level:
- `function X(in: WideString): WideString; safecall;`
  → `HRESULT X(BSTR in, BSTR* out)`
- `function Y(a, b: Integer): Integer; safecall;`
  → `HRESULT Y(int a, int b, int* out)`

### Release host-side interface refs before Shutdown

Same as Delphi: interface references from loaded DLLs must be released
**before** `Shutdown()`. With `Microsoft::WRL::ComPtr` and a block scope,
this is easiest:

```cpp
void RunExample() {
    Microsoft::WRL::ComPtr<IExample> example;
    AppCentral::TryGet<IExample>(example);
    // ... use it ...
}  // ComPtr destructor: Release

int main() {
    AppCentral::LoadPlugin(L"foo.dll");
    RunExample();          // example is fully gone here
    AppCentral::Shutdown(); // ok
}
```

### x86 vs x64

The build script targets x64. On x86 you'd need the `#pragma comment` that
maps the `__stdcall`-decorated name `_RegisterHost@4` back to `RegisterHost`.
The header has that prepared via `#ifdef _M_IX86`.

## API summary

```cpp
// Registration
template<typename T> static void Register(T* instance);
template<typename T> static void Register(std::function<T*(IUnknown*)> factory);
template<typename T> static void Unregister();

// Lookup (every T must have __declspec(uuid(...)) or be a MIDL_INTERFACE)
template<typename T> static bool TryGet(Microsoft::WRL::ComPtr<T>& out, IUnknown* params = nullptr);
template<typename T> static Microsoft::WRL::ComPtr<T> Get(IUnknown* params = nullptr);  // throws AppCentralInterfaceNotFound
template<typename T> static std::vector<Microsoft::WRL::ComPtr<T>> GetAllPlugins();

// Plugin management
static bool LoadPlugin(const wchar_t* filename);
static bool UnloadPlugin(const wchar_t* filename);
static bool PluginLoaded(const wchar_t* filename);
static size_t PluginCount();
static const std::wstring& PluginFilename(size_t idx);
static void Shutdown();
```

## Build

```
Build\build_cpp.bat
```

Produces `Output/CppHost.exe` and `Output/ExampleCppDLL.dll`.
