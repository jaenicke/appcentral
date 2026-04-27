# C++

AppCentral für C++ ist **header-only**. Eine einzige Datei `AppCentral.h`
enthält alle Implementierungen (mit C++17 `inline`-Variablen für die statischen
Felder), wird sowohl im Host als auch in DLLs eingebunden.

## Voraussetzungen

- Visual Studio 2019+ (MSVC, x64).
- C++17 oder neuer.

## Einbindung in ein eigenes Projekt

1. **`AppCentral.h`** in den Include-Pfad legen.
2. **`Interfaces.h`** für die Interface-Deklarationen.
3. Im Host: `#include "AppCentral.h"` reicht.
4. In einer DLL: `#include "AppCentral.h"` reicht. `RegisterHost` wird
   automatisch via `__declspec(dllexport)` exportiert.
5. Beim Linken: `ole32.lib` und `oleaut32.lib` für COM/BSTR.

## Beispiel - DLL

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
        std::wstring r = std::wstring(L"Hallo, ") + name + L"!";
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

Kompilieren als DLL:

```
cl /LD /EHsc /std:c++17 MyPlugin.cpp ole32.lib oleaut32.lib /Fe:MyPlugin.dll
```

## Beispiel - Host

```cpp
#include "AppCentral.h"
#include "Interfaces.h"
#include <cstdio>

int wmain(int argc, wchar_t* argv[])
{
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    AppCentral::LoadPlugin(L"MyPlugin.dll");

    {
        // ComPtr im inneren Scope - automatisches Release am Block-Ende
        Microsoft::WRL::ComPtr<IExample> example;
        AppCentral::TryGet<IExample>(example);

        BSTR result = nullptr;
        example->SayHello(SysAllocString(L"Welt"), &result);
        wprintf(L"%s\n", result);
        SysFreeString(result);
    }
    // hier hat ComPtr ihren Release schon gemacht

    AppCentral::Shutdown();
    CoUninitialize();
    return 0;
}
```

## Wichtige Regeln

### Interfaces als reine Vtable-Klassen mit `MIDL_INTERFACE`

```cpp
MIDL_INTERFACE("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
IExample : public IUnknown
{
    virtual HRESULT STDMETHODCALLTYPE SayHello(BSTR name, BSTR* pResult) = 0;
    virtual HRESULT STDMETHODCALLTYPE Add(int a, int b, int* pResult) = 0;
};
```

`MIDL_INTERFACE("...")` ist der MSVC-Idiom für `__declspec(uuid("..."))` - damit
funktioniert `__uuidof(IExample)` zur Compile-Zeit. Methoden müssen `pure
virtual` und `STDMETHODCALLTYPE` (= `__stdcall`) sein.

Die Signaturen entsprechen Delphis `safecall` auf Vtable-Ebene:
- `function X(in: WideString): WideString; safecall;`
  → `HRESULT X(BSTR in, BSTR* out)`
- `function Y(a, b: Integer): Integer; safecall;`
  → `HRESULT Y(int a, int b, int* out)`

### Host-Interface-Refs vor Shutdown freigeben

Wie bei Delphi: Interface-Referenzen aus geladenen DLLs müssen **vor**
`Shutdown()` freigegeben sein. Mit `Microsoft::WRL::ComPtr` per Block-Scope am
einfachsten:

```cpp
void RunExample() {
    Microsoft::WRL::ComPtr<IExample> example;
    AppCentral::TryGet<IExample>(example);
    // ... benutzen ...
}  // ComPtr-Destructor: Release

int main() {
    AppCentral::LoadPlugin(L"foo.dll");
    RunExample();          // example ist hier komplett weg
    AppCentral::Shutdown(); // ok
}
```

### x86 vs x64

Build-Skript ist x64. Auf x86 müsste das `#pragma comment` aktiv sein, das den
`__stdcall`-decorierten Namen `_RegisterHost@4` zurück auf `RegisterHost`
mapped. Der Header hat das per `#ifdef _M_IX86` schon vorbereitet.

## API-Übersicht

```cpp
// Registrierung
template<typename T> static void Register(T* instance);
template<typename T> static void Register(std::function<T*(IUnknown*)> factory);
template<typename T> static void Unregister();

// Abfrage (alle T müssen __declspec(uuid(...)) haben oder MIDL_INTERFACE sein)
template<typename T> static bool TryGet(Microsoft::WRL::ComPtr<T>& out, IUnknown* params = nullptr);
template<typename T> static Microsoft::WRL::ComPtr<T> Get(IUnknown* params = nullptr);  // wirft AppCentralInterfaceNotFound
template<typename T> static std::vector<Microsoft::WRL::ComPtr<T>> GetAllPlugins();

// Plugin-Verwaltung
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

Erzeugt `Output/CppHost.exe` und `Output/ExampleCppDLL.dll`.
