/**
 * AppCentral C++ host - with the modernised features
 */

#include "../../AppCentral.h"
#include "../Interfaces.h"

#include <cstdio>

void RunExample()
{
    Microsoft::WRL::ComPtr<IExample> example;
    if (!AppCentral::TryGet<IExample>(example)) {
        wprintf(L"ERROR: IExample not found!\n");
        return;
    }

    BSTR result = nullptr;
    example->SayHello(SysAllocString(L"World"), &result);
    if (result) {
        wprintf(L"IExample.SayHello: %s\n", result);
        SysFreeString(result);
    }

    int sum = 0;
    example->Add(3, 4, &sum);
    wprintf(L"IExample.Add(3, 4): %d\n", sum);
}

void RunAllPluginsDemo()
{
    auto allExamples = AppCentral::GetAllPlugins<IExample>();
    wprintf(L"Plugins offering IExample: %zu\n", allExamples.size());
    for (size_t i = 0; i < allExamples.size(); ++i) {
        BSTR result = nullptr;
        allExamples[i]->SayHello(SysAllocString(L"Plugin"), &result);
        if (result) {
            wprintf(L"  Plugin %zu: %s\n", i, result);
            SysFreeString(result);
        }
    }
}

void TestGetException()
{
    wprintf(L"\nTeste Get<unbekannt>...\n");
    try {
        auto p = AppCentral::Get<IExampleParams>();
        wprintf(L"  -> unexpected: interface found\n");
    } catch (const AppCentralInterfaceNotFound& e) {
        wprintf(L"  -> wie erwartet: %hs\n", e.what());
    }
}

int wmain(int argc, wchar_t* argv[])
{
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    wprintf(L"=== AppCentral C++ host (modernized) ===\n\n");

    const wchar_t* dllName = argc > 1 ? argv[1] : L"ExampleCppDLL.dll";

    wprintf(L"Loading %s...\n", dllName);
    if (!AppCentral::LoadPlugin(dllName)) {
        wprintf(L"ERROR: Could not load plugin\n");
        CoUninitialize();
        return 1;
    }
    wprintf(L"Loaded.\n");

    // Optional zweites Plugin
    if (argc > 2) {
        if (AppCentral::LoadPlugin(argv[2]))
            wprintf(L"Second plugin loaded: %s\n", argv[2]);
    }

    wprintf(L"\n--- Plugin list ---\n");
    for (size_t i = 0; i < AppCentral::PluginCount(); ++i)
        wprintf(L"  [%zu] %s\n", i, AppCentral::PluginFilename(i).c_str());

    wprintf(L"\n");
    RunExample();
    wprintf(L"\n");
    RunAllPluginsDemo();
    TestGetException();

    wprintf(L"\nShutdown...\n");
    AppCentral::Shutdown();
    wprintf(L"Done.\n");

    CoUninitialize();
    return 0;
}
