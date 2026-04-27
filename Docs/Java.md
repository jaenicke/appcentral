# Java

🇩🇪 [Deutsche Version](Java.de.md)

Java comes in two flavors:

1. **Java as host** — loads native AppCentral DLLs via JNA. A pure Java project.
2. **Java as DLL** — a native C bridge DLL that internally starts a JVM and
   contains the actual implementation in Java. The C bridge presents itself
   as a normal AppCentral plugin DLL to the outside world.

There is also a third, more exotic variant:

3. **Delphi loads Java classes directly via JNI** — without a C bridge DLL.
   See `DelphiJavaHost/`. The JNI bindings live in `AppCentral.JNI.pas`.

## Requirements

- JDK 8 or newer (tested with Eclipse Adoptium 25). For a 64-bit AppCentral,
  use a **64-bit JDK**.
- `JAVA_HOME` must point to the JDK.
- For the host: **JNA** (Java Native Access) as a library. Download:
  https://github.com/java-native-access/jna/releases — the build scripts
  expect `jna-5.14.0.jar` and `jna-platform-5.14.0.jar` in `JavaHost/lib/`.
- For the DLL: a **C compiler** (MSVC) for the bridge.

## Java as host

Uses JNA to load the DLL and make COM vtable calls. A custom `AppCentral`
helper class with `loadPlugin`, `tryGet`, `getAllPlugins`, `shutdown`. COM
method calls go through vtable indices:

```java
import com.sun.jna.*;

private static Pointer callGetInterface(Pointer comObj, boolean fromHost,
        Guid.GUID iid, Pointer params) {
    Pointer vtable = comObj.getPointer(0);
    long fnAddr = Pointer.nativeValue(vtable.getPointer(3L * Native.POINTER_SIZE));
    Function fn = Function.getFunction(new Pointer(fnAddr), Function.ALT_CONVENTION);
    ...
    int hr = fn.invokeInt(new Object[]{comObj, fromHost ? 1 : 0,
        iidRef.getPointer(), params, ppObj});
    ...
}
```

The `LocalProvider` is built using JNA `Callback` and native memory in order
to be passed to the DLL.

### Using it

```bash
javac -cp jna-5.14.0.jar;jna-platform-5.14.0.jar AppCentral.java IExampleProxy.java Main.java
java --enable-native-access=ALL-UNNAMED \
     -cp .;jna-5.14.0.jar;jna-platform-5.14.0.jar Main MyPlugin.dll
```

`--enable-native-access=ALL-UNNAMED` is required since Java 22 — without it
you'll see a warning (and a hard error in a future release).

### Example — host

```java
public class Main {
    public static void main(String[] args) {
        AppCentral ac = new AppCentral();
        ac.loadPlugin(args[0]);

        IExampleProxy ex = ac.tryGet(IExampleProxy.IID, IExampleProxy::new);
        if (ex != null) {
            System.out.println(ex.sayHello("World"));
            System.out.println(ex.add(3, 4));
            ex.release();
        }

        ac.shutdown();
    }
}
```

`IExampleProxy` is a custom class that does COM vtable calls at indices 3+:

```java
public class IExampleProxy {
    public static final Guid.GUID IID =
        new Guid.GUID("{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}");

    private final Pointer comPtr;
    private final Pointer vtable;

    public IExampleProxy(Pointer comPtr) {
        this.comPtr = comPtr;
        this.vtable = comPtr.getPointer(0);
    }

    public String sayHello(String name) {
        long fnAddr = Pointer.nativeValue(vtable.getPointer(3L * Native.POINTER_SIZE));
        Function fn = Function.getFunction(new Pointer(fnAddr), Function.ALT_CONVENTION);
        BSTR bstrName = OleAuto.INSTANCE.SysAllocString(name);
        PointerByReference pResult = new PointerByReference();
        int hr = fn.invokeInt(new Object[]{comPtr, bstrName.getPointer(), pResult});
        ...
    }
    ...
}
```

## Java as DLL

A **C bridge DLL** exports `RegisterHost` and implements the COM vtables
manually in C. Each method call is delegated via JNI to the Java class
`ExampleImpl`.

`ExampleJavaDLL.c` contains:

- COM vtable definitions (static structs).
- `JNI_CreateJavaVM` — starts a JVM on first access (or attaches to an
  existing JVM if the host is itself running Java).
- Method stubs that JNI-call into `ExampleImpl`.

`ExampleImpl.java`:

```java
public class ExampleImpl {
    private final String greeting = "Hello";
    public String sayHello(String name) {
        return greeting + ", " + name + "!";
    }
    public int add(int a, int b) {
        return a + b;
    }
}
```

### How to use it

1. Write the **Java class** (no COM markup needed — the C bridge handles it).
2. Write the **C bridge** with `JNI_CreateJavaVM`/`JNI_GetCreatedJavaVMs`,
   COM vtable definitions, and method stubs (example: `JavaDLL/ExampleJavaDLL.c`).
3. Build the Java class: `javac -d Output ExampleImpl.java`
4. Build the C bridge:
   ```
   cl /LD /I"%JAVA_HOME%\include" /I"%JAVA_HOME%\include\win32" \
      ExampleJavaDLL.c ole32.lib oleaut32.lib "%JAVA_HOME%\lib\jvm.lib" \
      /Fe:ExampleJavaDLL.dll
   ```
5. At runtime `jvm.dll` must be on `PATH`:
   `set PATH=%JAVA_HOME%\bin\server;%PATH%`

### Important notes for the DLL bridge

- **JVM detection**: at first call, try `JNI_GetCreatedJavaVMs`. If the host
  already has a JVM (e.g. we're running inside a Java host), attach to that
  one. Otherwise create a new one.
- **DLL pinning**: `GetModuleHandleEx` with `GET_MODULE_HANDLE_EX_FLAG_PIN`
  — so `FreeLibrary` doesn't unload the DLL while the JVM is still alive.
- **Don't call `DestroyJavaVM` from DllMain** — JNI doesn't allow that
  (loader-lock deadlock + heap corruption). The JVM stays alive until process
  exit. Even in `Provider_Shutdown` calling `DestroyJavaVM` is risky and is
  skipped in the example.
- **Classpath** is derived at runtime from the DLL's directory (via
  `GetModuleFileName`) so the `.class` files next to the DLL are found.

## Delphi loads Java classes directly

An alternate variant (`DelphiJavaHost/`) — the Delphi host loads a JVM itself
(using `AppCentral.JNI.pas` bindings) and uses the Java class directly — no
extra DLL needed:

```pascal
TJVM.Initialize('C:\path\to\class\files');
TAppCentral.Register<IExample>(TJavaExampleAdapter.Create('ExampleImpl'));

// IExample is now available, backed by a Java class
```

`TJavaExampleAdapter` is a `TInterfacedObject, IExample` that delegates calls
internally to the Java class via JNI. See `AppCentral.JNI.pas` for details.

## API summary (Java host)

```java
public class AppCentral {
    public boolean loadPlugin(String path);
    public boolean unloadPlugin(String filename);
    public boolean pluginLoaded(String path);
    public int pluginCount();
    public String pluginFilename(int idx);

    public <T> T tryGet(Guid.GUID iid, java.util.function.Function<Pointer, T> factory);
    public <T> T get(Guid.GUID iid, java.util.function.Function<Pointer, T> factory);  // throws RuntimeException
    public <T> List<T> getAllPlugins(Guid.GUID iid, java.util.function.Function<Pointer, T> factory);

    public void shutdown();
}
```

## Build

```
Build\build_java_host.bat
Build\build_java_dll.bat
```

Produces `Output/Main.class` (+ JNA jars), `Output/ExampleJavaDLL.dll`,
`Output/ExampleImpl.class`, and a convenience `Build/run_java_host.cmd`
launcher that runs the host with the right JAVA_HOME and classpath.
