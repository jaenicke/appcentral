# Java

Java kommt in zwei Varianten vor:

1. **Java als Host** - lädt native AppCentral-DLLs via JNA. Reines Java-Projekt.
2. **Java als DLL** - eine native C-Bridge-DLL, die intern eine JVM startet
   und die eigentliche Implementierung in Java enthält. Die C-Bridge tarnt sich
   nach außen als normale AppCentral-Plugin-DLL.

Zusätzlich gibt es eine dritte, exotischere Variante:

3. **Delphi lädt Java-Klassen direkt via JNI** - ohne C-Bridge-DLL. Siehe
   `DelphiJavaHost/`. Die JNI-Bindings sind in `AppCentral.JNI.pas`.

## Voraussetzungen

- JDK 8 oder neuer (getestet mit Eclipse Adoptium 25). Bei einem 64-bit-AppCentral
  unbedingt ein **64-bit-JDK** verwenden.
- `JAVA_HOME` muss auf das JDK zeigen.
- Für den Host: **JNA** (Java Native Access) als Bibliothek.
  Download: https://github.com/java-native-access/jna/releases - die Build-Skripte
  erwarten `jna-5.14.0.jar` und `jna-platform-5.14.0.jar` in
  `JavaHost/lib/`.
- Für die DLL: ein **C-Compiler** (MSVC) für die Bridge.

## Java als Host

Verwendet JNA, um die DLL zu laden und COM-Vtable-Aufrufe zu machen. Eigene
Helper-Klasse `AppCentral` mit Methoden `loadPlugin`, `tryGet`, `getAllPlugins`,
`shutdown`. COM-Methodenaufruf erfolgt über die Vtable-Indizes:

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

Eigener `LocalProvider` wird mit `JNA Callback`-Memory in nativem Speicher
gebaut, um an die DLL übergeben zu werden.

### Einbindung

```bash
javac -cp jna-5.14.0.jar;jna-platform-5.14.0.jar AppCentral.java IExampleProxy.java Main.java
java --enable-native-access=ALL-UNNAMED \
     -cp .;jna-5.14.0.jar;jna-platform-5.14.0.jar Main MyPlugin.dll
```

`--enable-native-access=ALL-UNNAMED` ist seit Java 22 nötig, sonst Warnung
(wird in späteren Versionen als Fehler gekennzeichnet werden).

### Beispiel - Host

```java
public class Main {
    public static void main(String[] args) {
        AppCentral ac = new AppCentral();
        ac.loadPlugin(args[0]);

        IExampleProxy ex = ac.tryGet(IExampleProxy.IID, IExampleProxy::new);
        if (ex != null) {
            System.out.println(ex.sayHello("Welt"));
            System.out.println(ex.add(3, 4));
            ex.release();
        }

        ac.shutdown();
    }
}
```

`IExampleProxy` ist eine eigene Klasse, die COM-Vtable-Aufrufe an Indizes 3+
macht:

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

## Java als DLL

Eine **C-Bridge-DLL** exportiert `RegisterHost` und implementiert die
COM-Vtables manuell in C. Bei jedem Aufruf einer Methode wird via JNI in die
Java-Klasse `ExampleImpl` delegiert.

`ExampleJavaDLL.c` enthält:

- COM-Vtable-Definitionen (statische Structs).
- `JNI_CreateJavaVM` - startet eine JVM beim ersten Zugriff (oder hängt sich
  an eine vorhandene JVM, wenn der Host selbst Java ist).
- Method-Stubs, die JNI-Aufrufe gegen `ExampleImpl` machen.

`ExampleImpl.java`:

```java
public class ExampleImpl {
    private final String greeting = "Hallo";
    public String sayHello(String name) {
        return greeting + ", " + name + "!";
    }
    public int add(int a, int b) {
        return a + b;
    }
}
```

### Einbindung

1. **Java-Klasse** schreiben (kein COM-Markup nötig - die C-Bridge macht das).
2. **C-Bridge** anlegen mit `JNI_CreateJavaVM`/`JNI_GetCreatedJavaVMs`,
   COM-Vtable-Definitionen und Method-Stubs (Beispiel: `JavaDLL/ExampleJavaDLL.c`).
3. Build der Java-Klasse: `javac -d Output ExampleImpl.java`
4. Build der C-Bridge:
   ```
   cl /LD /I"%JAVA_HOME%\include" /I"%JAVA_HOME%\include\win32" \
      ExampleJavaDLL.c ole32.lib oleaut32.lib "%JAVA_HOME%\lib\jvm.lib" \
      /Fe:ExampleJavaDLL.dll
   ```
5. Zur Laufzeit muss `jvm.dll` im `PATH` sein:
   `set PATH=%JAVA_HOME%\bin\server;%PATH%`

### Wichtige Punkte beim DLL-Bridge

- **JVM-Erkennung**: Beim Aufruf zuerst `JNI_GetCreatedJavaVMs` versuchen. Wenn
  der Host bereits eine JVM hat (z. B. wir laufen in einem Java-Host), an
  diese anhängen. Sonst neue erstellen.
- **DLL-Pinning**: `GetModuleHandleEx` mit `GET_MODULE_HANDLE_EX_FLAG_PIN` -
  damit `FreeLibrary` die DLL nicht entlädt, solange die JVM noch läuft.
- **`DestroyJavaVM` NICHT in DllMain aufrufen** - JNI darf das nicht aus dem
  DllMain (Loader-Lock-Deadlock + Heap-Korruption). Die JVM bleibt bis zum
  Prozess-Exit aktiv. Auch im `Provider_Shutdown` ist DestroyJavaVM riskant
  und wird im Beispiel ausgelassen.
- **Classpath** zur Laufzeit aus dem DLL-Verzeichnis ableiten (via
  `GetModuleFileName`), damit die `.class`-Dateien neben der DLL gefunden werden.

## Delphi lädt Java-Klassen direkt

Eine alternative Variante (`DelphiJavaHost/`) - der Delphi-Host lädt eine
JVM selbst (mit `AppCentral.JNI.pas`-Bindings) und benutzt die Java-Klasse
direkt - keine zusätzliche DLL nötig:

```pascal
TJVM.Initialize('C:\Pfad\zu\Class-Dateien');
TAppCentral.Register<IExample>(TJavaExampleAdapter.Create('ExampleImpl'));

// Jetzt ist IExample als Java-Klasse verfügbar
```

`TJavaExampleAdapter` ist ein `TInterfacedObject, IExample`, der die Aufrufe
intern via JNI an die Java-Klasse delegiert. Details siehe `AppCentral.JNI.pas`.

## API-Übersicht (Java Host)

```java
public class AppCentral {
    public boolean loadPlugin(String path);
    public boolean unloadPlugin(String filename);
    public boolean pluginLoaded(String path);
    public int pluginCount();
    public String pluginFilename(int idx);

    public <T> T tryGet(Guid.GUID iid, java.util.function.Function<Pointer, T> factory);
    public <T> T get(Guid.GUID iid, java.util.function.Function<Pointer, T> factory);  // wirft RuntimeException
    public <T> List<T> getAllPlugins(Guid.GUID iid, java.util.function.Function<Pointer, T> factory);

    public void shutdown();
}
```

## Build

```
Build\build_java_host.bat
Build\build_java_dll.bat
```

Erzeugt `Output/Main.class` (+ JNA-JARs), `Output/ExampleJavaDLL.dll`
und `Output/ExampleImpl.class` sowie ein Komfort-Launcher
`Build/run_java_host.cmd`, der den Host mit korrektem JAVA_HOME und
Classpath startet.
