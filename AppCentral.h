/**
 * Copyright (c) 2026 Sebastian Jänicke (github.com/jaenicke)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 *
 * AppCentral.h - cross-language interface exchange (C++)
 * With FromHost flag for plugin-to-plugin routing through the host.
 */

#pragma once

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <unknwn.h>
#include <oleauto.h>
#include <wrl/client.h>

#include <map>
#include <vector>
#include <functional>
#include <string>
#include <stdexcept>
#include <algorithm>

// ============================================================================
// IAppCentralProvider - with FromHost flag (new GUID to avoid vtable conflicts)
// ============================================================================

// {F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}
MIDL_INTERFACE("F7E8D9C1-B1A2-4E3F-8071-926354AABBCC")
IAppCentralProvider : public IUnknown
{
    virtual HRESULT STDMETHODCALLTYPE GetInterface(
        BOOL FromHost, REFGUID riid, IUnknown* pParams, IUnknown** ppObj) = 0;
    virtual HRESULT STDMETHODCALLTYPE Shutdown() = 0;
};

// ============================================================================
// Exception for Get<T>
// ============================================================================
class AppCentralInterfaceNotFound : public std::runtime_error {
public:
    AppCentralInterfaceNotFound() : std::runtime_error("AppCentral: interface not registered") {}
};

// ============================================================================
// Internal types
// ============================================================================

namespace AppCentralDetail {

struct GUIDLess {
    bool operator()(const GUID& a, const GUID& b) const {
        return memcmp(&a, &b, sizeof(GUID)) < 0;
    }
};

struct RegistryEntry {
    IUnknown* instance = nullptr;
    std::function<IUnknown*(IUnknown*)> factory;
};

struct PluginInfo {
    HMODULE handle = nullptr;
    IAppCentralProvider* provider = nullptr;
    std::wstring filename;
};

class LocalProvider : public IAppCentralProvider
{
    LONG m_refCount = 1;
public:
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override;
    ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&m_refCount); }
    ULONG STDMETHODCALLTYPE Release() override {
        LONG ref = InterlockedDecrement(&m_refCount);
        if (ref == 0) delete this;
        return ref;
    }
    HRESULT STDMETHODCALLTYPE GetInterface(
        BOOL FromHost, REFGUID riid, IUnknown* pParams, IUnknown** ppObj) override;
    HRESULT STDMETHODCALLTYPE Shutdown() override;
};

inline std::map<GUID, RegistryEntry, GUIDLess> g_registry;
inline std::vector<PluginInfo> g_plugins;
inline IAppCentralProvider* g_hostProvider = nullptr;
inline LocalProvider* g_localProvider = nullptr;

inline void EnsureInitialized() {
    if (!g_localProvider) {
        g_localProvider = new LocalProvider();
    }
}

inline HRESULT ResolveLocalRegistry(REFGUID riid, IUnknown* pParams, IUnknown** ppObj) {
    *ppObj = nullptr;
    auto it = g_registry.find(riid);
    if (it != g_registry.end()) {
        IUnknown* intf = nullptr;
        if (it->second.factory) {
            intf = it->second.factory(pParams);
        } else {
            intf = it->second.instance;
        }
        if (intf) {
            return intf->QueryInterface(riid, (void**)ppObj);
        }
    }
    return E_NOINTERFACE;
}

// Routing logic - same as in the Delphi version
inline HRESULT ResolveInterface(BOOL fromHost, REFGUID riid, IUnknown* pParams, IUnknown** ppObj) {
    EnsureInitialized();
    *ppObj = nullptr;

    // 1. Local registry
    if (ResolveLocalRegistry(riid, pParams, ppObj) == S_OK)
        return S_OK;

    // 2. If not "from host" and we know the host -> ask the host
    if (!fromHost && g_hostProvider) {
        HRESULT hr = g_hostProvider->GetInterface(FALSE, riid, pParams, ppObj);
        if (hr == S_OK) return S_OK;
    }

    // 3. Ask plugins (FromHost=TRUE so the plugin doesn't ask back)
    for (auto& plugin : g_plugins) {
        if (plugin.provider) {
            HRESULT hr = plugin.provider->GetInterface(TRUE, riid, pParams, ppObj);
            if (hr == S_OK) return S_OK;
        }
    }

    return E_NOINTERFACE;
}

} // namespace AppCentralDetail

// ============================================================================
// AppCentral - central class
// ============================================================================

class AppCentral
{
public:
    template<typename T>
    static void Register(T* instance) {
        AppCentralDetail::EnsureInitialized();
        auto& entry = AppCentralDetail::g_registry[__uuidof(T)];
        entry.instance = instance;
        entry.factory = nullptr;
    }

    template<typename T>
    static void Register(std::function<T*(IUnknown*)> factory) {
        AppCentralDetail::EnsureInitialized();
        auto& entry = AppCentralDetail::g_registry[__uuidof(T)];
        entry.instance = nullptr;
        entry.factory = [factory](IUnknown* params) -> IUnknown* {
            return factory(params);
        };
    }

    template<typename T>
    static void Unregister() {
        AppCentralDetail::g_registry.erase(__uuidof(T));
    }

    /// Try to get the interface. Returns false if not found.
    template<typename T>
    static bool TryGet(Microsoft::WRL::ComPtr<T>& out, IUnknown* params = nullptr) {
        IUnknown* obj = nullptr;
        HRESULT hr = AppCentralDetail::ResolveInterface(FALSE, __uuidof(T), params, &obj);
        if (hr != S_OK || !obj) {
            out.Reset();
            return false;
        }
        T* result = nullptr;
        HRESULT qhr = obj->QueryInterface(__uuidof(T), (void**)&result);
        obj->Release();
        if (qhr != S_OK) {
            out.Reset();
            return false;
        }
        out.Attach(result);
        return true;
    }

    /// Throws AppCentralInterfaceNotFound if not found.
    template<typename T>
    static Microsoft::WRL::ComPtr<T> Get(IUnknown* params = nullptr) {
        Microsoft::WRL::ComPtr<T> result;
        if (!TryGet<T>(result, params))
            throw AppCentralInterfaceNotFound();
        return result;
    }

    /// All plugins that offer the interface.
    template<typename T>
    static std::vector<Microsoft::WRL::ComPtr<T>> GetAllPlugins() {
        std::vector<Microsoft::WRL::ComPtr<T>> result;
        for (auto& plugin : AppCentralDetail::g_plugins) {
            if (!plugin.provider) continue;
            IUnknown* obj = nullptr;
            if (plugin.provider->GetInterface(TRUE, __uuidof(T), nullptr, &obj) == S_OK && obj) {
                T* typed = nullptr;
                if (obj->QueryInterface(__uuidof(T), (void**)&typed) == S_OK) {
                    Microsoft::WRL::ComPtr<T> ptr;
                    ptr.Attach(typed);
                    result.push_back(ptr);
                }
                obj->Release();
            }
        }
        return result;
    }

    /// Load a plugin (with filename dedup). Returns true on success.
    static inline bool LoadPlugin(const wchar_t* filename) {
        using RegisterHostProc = void* (__stdcall*)(void*);
        AppCentralDetail::EnsureInitialized();

        // Already loaded?
        if (PluginLoaded(filename)) return true;

        HMODULE handle = ::LoadLibraryW(filename);
        if (!handle) return false;

        auto proc = (RegisterHostProc)::GetProcAddress(handle, "RegisterHost");
        if (!proc) { ::FreeLibrary(handle); return false; }

        AppCentralDetail::g_localProvider->AddRef();
        auto* dllProvider = static_cast<IAppCentralProvider*>(
            proc(static_cast<void*>(AppCentralDetail::g_localProvider)));
        if (!dllProvider) { ::FreeLibrary(handle); return false; }

        AppCentralDetail::PluginInfo plugin;
        plugin.handle = handle;
        plugin.provider = dllProvider;
        plugin.filename = filename;
        AppCentralDetail::g_plugins.push_back(plugin);
        return true;
    }

    static inline bool UnloadPlugin(const wchar_t* filename) {
        auto& plugins = AppCentralDetail::g_plugins;
        for (auto it = plugins.begin(); it != plugins.end(); ++it) {
            if (_wcsicmp(GetBaseName(it->filename).c_str(),
                         GetBaseName(filename).c_str()) == 0) {
                if (it->provider) {
                    try { it->provider->Shutdown(); } catch (...) {}
                    it->provider->Release();
                }
                HMODULE h = it->handle;
                plugins.erase(it);
                if (h) ::FreeLibrary(h);
                return true;
            }
        }
        return false;
    }

    static inline bool PluginLoaded(const wchar_t* filename) {
        std::wstring name = GetBaseName(filename);
        for (auto& p : AppCentralDetail::g_plugins) {
            if (_wcsicmp(GetBaseName(p.filename).c_str(), name.c_str()) == 0)
                return true;
        }
        return false;
    }

    static inline size_t PluginCount() { return AppCentralDetail::g_plugins.size(); }
    static inline const std::wstring& PluginFilename(size_t idx) {
        return AppCentralDetail::g_plugins[idx].filename;
    }

    static inline void Shutdown() {
        for (auto& plugin : AppCentralDetail::g_plugins) {
            if (plugin.provider) plugin.provider->Shutdown();
        }
        std::vector<HMODULE> handles;
        for (auto& plugin : AppCentralDetail::g_plugins) {
            handles.push_back(plugin.handle);
            if (plugin.provider) {
                plugin.provider->Release();
                plugin.provider = nullptr;
            }
        }
        AppCentralDetail::g_plugins.clear();
        for (auto h : handles) {
            if (h) ::FreeLibrary(h);
        }
    }

    static inline IAppCentralProvider* HandleRegisterHost(IAppCentralProvider* hostProvider) {
        AppCentralDetail::EnsureInitialized();
        AppCentralDetail::g_hostProvider = hostProvider;
        if (hostProvider) hostProvider->AddRef();
        AppCentralDetail::g_localProvider->AddRef();
        return AppCentralDetail::g_localProvider;
    }

private:
    static inline std::wstring GetBaseName(const std::wstring& path) {
        size_t pos = path.find_last_of(L"\\/");
        return (pos == std::wstring::npos) ? path : path.substr(pos + 1);
    }
};

// ============================================================================
// LocalProvider implementation
// ============================================================================

namespace AppCentralDetail {

inline HRESULT STDMETHODCALLTYPE LocalProvider::QueryInterface(REFIID riid, void** ppv) {
    if (riid == IID_IUnknown || riid == __uuidof(IAppCentralProvider)) {
        *ppv = static_cast<IAppCentralProvider*>(this);
        AddRef();
        return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
}

inline HRESULT STDMETHODCALLTYPE LocalProvider::GetInterface(
    BOOL FromHost, REFGUID riid, IUnknown* pParams, IUnknown** ppObj)
{
    return ResolveInterface(FromHost, riid, pParams, ppObj);
}

inline HRESULT STDMETHODCALLTYPE LocalProvider::Shutdown() {
    if (g_hostProvider) {
        g_hostProvider->Release();
        g_hostProvider = nullptr;
    }
    return S_OK;
}

} // namespace AppCentralDetail

// ============================================================================
// RegisterHost export (pointer-based for cross-language compatibility)
// ============================================================================

extern "C" __declspec(dllexport)
void* __stdcall RegisterHost(void* hostProvider)
{
    return static_cast<void*>(
        AppCentral::HandleRegisterHost(static_cast<IAppCentralProvider*>(hostProvider)));
}

#ifdef _M_IX86
#pragma comment(linker, "/EXPORT:RegisterHost=_RegisterHost@4")
#endif
