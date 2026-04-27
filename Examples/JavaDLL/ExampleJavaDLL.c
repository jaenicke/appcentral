/**
 * ExampleJavaDLL.c - C bridge for the Java DLL
 *
 * Exports RegisterHost and creates COM objects that delegate via JNI
 * to the Java class ExampleImpl.
 *
 * Kompilieren (MSVC):
 *   cl /LD /I"%JAVA_HOME%\include" /I"%JAVA_HOME%\include\win32"
 *      ExampleJavaDLL.c ole32.lib oleaut32.lib
 *      "%JAVA_HOME%\lib\jvm.lib" /Fe:ExampleJavaDLL.dll
 *
 * Voraussetzung: JAVA_HOME zeigt auf ein JDK, jvm.dll muss im PATH sein.
 *   set PATH=%JAVA_HOME%\bin\server;%PATH%
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <unknwn.h>
#include <oleauto.h>
#include <jni.h>
#include <stdio.h>
#include <string.h>

/* ========================================================================
 * GUID definitions (must match Delphi/C++)
 * ======================================================================== */

// {F7E8D9C1-B1A2-4E3F-8071-926354AABBCC} - neue GUID wegen FromHost-Flag
static const GUID IID_IAppCentralProvider =
    {0xF7E8D9C1, 0xB1A2, 0x4E3F, {0x80, 0x71, 0x92, 0x63, 0x54, 0xAA, 0xBB, 0xCC}};

// {A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
static const GUID IID_IExample =
    {0xA1B2C3D4, 0xE5F6, 0x7890, {0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90}};

/* ========================================================================
 * JVM-Management
 * ======================================================================== */

static JavaVM* g_jvm = NULL;
static JNIEnv* g_env = NULL;
static jobject g_exampleImpl = NULL;  /* Globale Referenz auf ExampleImpl */
static IUnknown* g_hostProvider = NULL;
static int g_ownsJVM = 0;  /* 1 = wir haben JVM erstellt, 0 = an existierende attached */
static HMODULE g_hModule = NULL;  /* Own module handle (for path lookup) */
static char g_classPathOption[1024];  /* Buffer for classpath option */

static int InitJVM(void) {
    if (g_jvm != NULL) return 0;

    /* Erst pruefen ob bereits eine JVM existiert (e.g. Java-Host) */
    JavaVM* existingJVMs[1];
    jsize numVMs = 0;
    jint rc = JNI_GetCreatedJavaVMs(existingJVMs, 1, &numVMs);

    if (rc == JNI_OK && numVMs > 0) {
        /* An existierende JVM anhaengen */
        g_jvm = existingJVMs[0];
        rc = (*g_jvm)->GetEnv(g_jvm, (void**)&g_env, JNI_VERSION_1_8);
        if (rc == JNI_EDETACHED) {
            rc = (*g_jvm)->AttachCurrentThread(g_jvm, (void**)&g_env, NULL);
        }
        if (rc != JNI_OK) {
            fprintf(stderr, "Could not attach to JVM: %d\n", rc);
            return -1;
        }
        g_ownsJVM = 0;
    } else {
        /* Create our own JVM - pin our DLL and jvm.dll
         * so FreeLibrary doesn't unload them while the JVM is running.
         * Otherwise the host crashes on shutdown. */
        HMODULE pinnedSelf;
        GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN |
                           GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                           (LPCWSTR)&InitJVM, &pinnedSelf);
        HMODULE pinnedJvm;
        GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN, L"jvm.dll", &pinnedJvm);
        /* Create a new JVM - derive classpath from the DLL directory */
        char dllPath[MAX_PATH];
        GetModuleFileNameA(g_hModule, dllPath, MAX_PATH);
        /* Find the last backslash and cut the string there */
        char* lastBs = strrchr(dllPath, '\\');
        if (lastBs) *lastBs = '\0';

        snprintf(g_classPathOption, sizeof(g_classPathOption),
                 "-Djava.class.path=%s", dllPath);

        JavaVMInitArgs vm_args;
        JavaVMOption options[1];
        options[0].optionString = g_classPathOption;
        vm_args.version = JNI_VERSION_1_8;
        vm_args.nOptions = 1;
        vm_args.options = options;
        vm_args.ignoreUnrecognized = JNI_FALSE;

        rc = JNI_CreateJavaVM(&g_jvm, (void**)&g_env, &vm_args);
        if (rc != JNI_OK) {
            fprintf(stderr, "Could not create JVM: %d\n", rc);
            return -1;
        }
        g_ownsJVM = 1;
    }

    /* ExampleImpl instanziieren */
    jclass cls = (*g_env)->FindClass(g_env, "ExampleImpl");
    if (!cls) {
        if ((*g_env)->ExceptionCheck(g_env)) {
            (*g_env)->ExceptionDescribe(g_env);
            (*g_env)->ExceptionClear(g_env);
        }
        fprintf(stderr, "ExampleImpl.class not found\n");
        return -1;
    }

    jmethodID ctor = (*g_env)->GetMethodID(g_env, cls, "<init>", "()V");
    jobject local = (*g_env)->NewObject(g_env, cls, ctor);
    g_exampleImpl = (*g_env)->NewGlobalRef(g_env, local);
    (*g_env)->DeleteLocalRef(g_env, local);
    (*g_env)->DeleteLocalRef(g_env, cls);

    return 0;
}

static void DestroyJVM(void) {
    if (g_env && g_exampleImpl) {
        (*g_env)->DeleteGlobalRef(g_env, g_exampleImpl);
        g_exampleImpl = NULL;
    }
    /* Do NOT destroy the JVM:
     * - Bei attached JVM (Java-Host): gehoert dem Host
     * - For our own JVM: DestroyJavaVM is unstable when called from other
     *   threads/loaders and can cause heap corruption.
     *   The OS cleans up the JVM at process exit. */
    g_env = NULL;
    /* g_jvm stays set so that on reloading the DLL
     * the existing JVM can be reused. */
}

/* ========================================================================
 * ExampleCOM - COM-Objekt das an Java delegiert
 * ======================================================================== */

typedef struct ExampleCOM ExampleCOM;

/* Vtable for IExample */
typedef struct {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(ExampleCOM*, REFIID, void**);
    ULONG   (STDMETHODCALLTYPE *AddRef)(ExampleCOM*);
    ULONG   (STDMETHODCALLTYPE *Release)(ExampleCOM*);
    HRESULT (STDMETHODCALLTYPE *SayHello)(ExampleCOM*, BSTR, BSTR*);
    HRESULT (STDMETHODCALLTYPE *Add)(ExampleCOM*, int, int, int*);
} IExampleVtbl;

struct ExampleCOM {
    IExampleVtbl* lpVtbl;
    LONG refCount;
};

static HRESULT STDMETHODCALLTYPE Example_QueryInterface(ExampleCOM* self, REFIID riid, void** ppv) {
    if (IsEqualGUID(riid, &IID_IUnknown) || IsEqualGUID(riid, &IID_IExample)) {
        *ppv = self;
        self->lpVtbl->AddRef(self);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE Example_AddRef(ExampleCOM* self) {
    return InterlockedIncrement(&self->refCount);
}

static ULONG STDMETHODCALLTYPE Example_Release(ExampleCOM* self) {
    LONG ref = InterlockedDecrement(&self->refCount);
    if (ref == 0) {
        CoTaskMemFree(self);
    }
    return ref;
}

static HRESULT STDMETHODCALLTYPE Example_SayHello(ExampleCOM* self, BSTR name, BSTR* pResult) {
    if (!g_env || !g_exampleImpl) return E_FAIL;

    /* BSTR -> Java String */
    jstring jName = (*g_env)->NewString(g_env, (const jchar*)name, SysStringLen(name));

    /* ExampleImpl.sayHello(name) aufrufen */
    jclass cls = (*g_env)->GetObjectClass(g_env, g_exampleImpl);
    jmethodID mid = (*g_env)->GetMethodID(g_env, cls, "sayHello",
        "(Ljava/lang/String;)Ljava/lang/String;");
    jstring jResult = (jstring)(*g_env)->CallObjectMethod(g_env, g_exampleImpl, mid, jName);

    (*g_env)->DeleteLocalRef(g_env, jName);
    (*g_env)->DeleteLocalRef(g_env, cls);

    if (jResult) {
        const jchar* chars = (*g_env)->GetStringChars(g_env, jResult, NULL);
        jsize len = (*g_env)->GetStringLength(g_env, jResult);
        *pResult = SysAllocStringLen((const OLECHAR*)chars, len);
        (*g_env)->ReleaseStringChars(g_env, jResult, chars);
        (*g_env)->DeleteLocalRef(g_env, jResult);
    } else {
        *pResult = SysAllocString(L"");
    }

    return S_OK;
}

static HRESULT STDMETHODCALLTYPE Example_Add(ExampleCOM* self, int a, int b, int* pResult) {
    if (!g_env || !g_exampleImpl) return E_FAIL;

    jclass cls = (*g_env)->GetObjectClass(g_env, g_exampleImpl);
    jmethodID mid = (*g_env)->GetMethodID(g_env, cls, "add", "(II)I");
    *pResult = (*g_env)->CallIntMethod(g_env, g_exampleImpl, mid, a, b);
    (*g_env)->DeleteLocalRef(g_env, cls);

    return S_OK;
}

static IExampleVtbl g_exampleVtbl = {
    Example_QueryInterface,
    Example_AddRef,
    Example_Release,
    Example_SayHello,
    Example_Add
};

static ExampleCOM* CreateExampleCOM(void) {
    ExampleCOM* obj = (ExampleCOM*)CoTaskMemAlloc(sizeof(ExampleCOM));
    obj->lpVtbl = &g_exampleVtbl;
    obj->refCount = 1;
    return obj;
}

/* ========================================================================
 * LocalProvider - COM object for IAppCentralProvider
 * ======================================================================== */

typedef struct LocalProvider LocalProvider;

typedef struct {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(LocalProvider*, REFIID, void**);
    ULONG   (STDMETHODCALLTYPE *AddRef)(LocalProvider*);
    ULONG   (STDMETHODCALLTYPE *Release)(LocalProvider*);
    HRESULT (STDMETHODCALLTYPE *GetInterface)(LocalProvider*, BOOL, REFGUID, IUnknown*, IUnknown**);
    HRESULT (STDMETHODCALLTYPE *Shutdown)(LocalProvider*);
} IAppCentralProviderVtbl;

struct LocalProvider {
    IAppCentralProviderVtbl* lpVtbl;
    LONG refCount;
};

static HRESULT STDMETHODCALLTYPE Provider_QueryInterface(LocalProvider* self, REFIID riid, void** ppv) {
    if (IsEqualGUID(riid, &IID_IUnknown) || IsEqualGUID(riid, &IID_IAppCentralProvider)) {
        *ppv = self;
        self->lpVtbl->AddRef(self);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE Provider_AddRef(LocalProvider* self) {
    return InterlockedIncrement(&self->refCount);
}

static ULONG STDMETHODCALLTYPE Provider_Release(LocalProvider* self) {
    LONG ref = InterlockedDecrement(&self->refCount);
    /* g_localProvider is a static variable - DO NOT free! */
    return (ref < 0) ? 0 : (ULONG)ref;
}

static ExampleCOM* g_exampleCOM = NULL;

static HRESULT STDMETHODCALLTYPE Provider_GetInterface(
    LocalProvider* self, BOOL fromHost, REFGUID riid, IUnknown* pParams, IUnknown** ppObj)
{
    /* fromHost is not further evaluated - the Java DLL has no sub-plugins. */
    (void)fromHost;
    *ppObj = NULL;

    if (IsEqualGUID(riid, &IID_IExample)) {
        if (!g_exampleCOM) {
            g_exampleCOM = CreateExampleCOM();
        }
        *ppObj = (IUnknown*)g_exampleCOM;
        g_exampleCOM->lpVtbl->AddRef(g_exampleCOM);
        return S_OK;
    }

    return E_NOINTERFACE;
}

static HRESULT STDMETHODCALLTYPE Provider_Shutdown(LocalProvider* self) {
    /* Host-Provider freigeben */
    if (g_hostProvider) {
        g_hostProvider->lpVtbl->Release(g_hostProvider);
        g_hostProvider = NULL;
    }
    /* Do not destroy the JVM - it lives until process exit.
     * The DLL is pinned, so it can't be unloaded. */
    return S_OK;
}

static IAppCentralProviderVtbl g_providerVtbl = {
    Provider_QueryInterface,
    Provider_AddRef,
    Provider_Release,
    Provider_GetInterface,
    Provider_Shutdown
};

static LocalProvider g_localProvider = {&g_providerVtbl, 1};

/* ========================================================================
 * DLL-Export: RegisterHost
 * ======================================================================== */

__declspec(dllexport)
IUnknown* __stdcall RegisterHost(IUnknown* hostProvider)
{
    if (InitJVM() != 0) {
        return NULL;
    }

    g_hostProvider = hostProvider;
    if (hostProvider) {
        hostProvider->lpVtbl->AddRef(hostProvider);
    }

    g_localProvider.refCount++;
    return (IUnknown*)&g_localProvider;
}

/* ========================================================================
 * DLL Entry Point
 * ======================================================================== */

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID lpReserved)
{
    switch (reason) {
    case DLL_PROCESS_ATTACH:
        g_hModule = hModule;
        CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
        break;
    case DLL_PROCESS_DETACH:
        /* JVM is destroyed in Provider_Shutdown, NOT here
         * (DllMain must not call any JNI operations). */
        CoUninitialize();
        break;
    }
    return TRUE;
}
