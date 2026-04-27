# PowerShell

PowerShell ist nur als **Host** unterstützt - PowerShell selbst kann keine
nativen DLLs erzeugen.

Die Implementierung ist zweigeteilt: die Integrations-Bibliothek
`AppCentral.ps1` im AppCentral-Root und das Sample-Driver-Skript
`Examples/PowerShellHost/main.ps1`. Der Driver dot-sourct die Library und
benutzt deren `AppCentralPS.AppCentral`-Klasse. Da PowerShell
COM-Objekte automatisch als `System.__ComObject` wrapt (ohne Methoden,
Late-Bound-only), wird die gesamte COM-Logik in C# gekapselt und per
`Add-Type` zur Laufzeit kompiliert. PowerShell ruft dann nur noch die
C#-Wrapper-Methoden auf.

## Voraussetzungen

- Windows PowerShell 5.1 oder PowerShell 7+ (beide getestet).
- .NET Framework (für Windows PS 5.1) bzw. .NET Runtime (für PS 7+).

## Einbindung

Es gibt nichts zu installieren - das Skript ist self-contained. Einfach
ausführen:

```powershell
.\main.ps1 -DllPath C:\Pfad\Plugin.dll [-SecondDllPath ...]
```

## Beispiel - Host

Library `AppCentral.ps1` (gekürzt - vollständig im AppCentral-Root):

```powershell
$Source = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace AppCentralPS
{
    [ComImport]
    [Guid("F7E8D9C1-B1A2-4E3F-8071-926354AABBCC")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAppCentralProvider
    {
        [PreserveSig]
        int GetInterface([MarshalAs(UnmanagedType.Bool)] bool fromHost,
            ref Guid iid,
            [MarshalAs(UnmanagedType.IUnknown)] object pParams,
            [MarshalAs(UnmanagedType.IUnknown)] out object obj);
        [PreserveSig]
        int Shutdown();
    }

    [ComImport]
    [Guid("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IExample
    {
        [return: MarshalAs(UnmanagedType.BStr)]
        string SayHello([MarshalAs(UnmanagedType.BStr)] string name);
        int Add(int a, int b);
    }

    public class AppCentral
    {
        // ... LoadPlugin, ExampleSayHello, ExampleAdd, etc. ...
    }
}
"@

Add-Type -TypeDefinition $Source -Language CSharp

$ac = New-Object AppCentralPS.AppCentral
$ac.LoadPlugin($DllPath) | Out-Null

Write-Host ("SayHello: " + $ac.ExampleSayHello("Welt"))
Write-Host ("Add: " + $ac.ExampleAdd(3, 4))

$ac.Shutdown()
```

## Wichtige Regeln

### Logik in C#, nicht in PowerShell

PowerShell wrapt COM-Objekte als `System.__ComObject`. Diese Wrapper haben
keine Methoden für unsere Custom-Interfaces - nur Late-Binding via Reflection,
was bei nicht-Dispatch-Interfaces nicht klappt.

Lösung: alle COM-Aufrufe in der C#-Klasse halten und nur **String/Int/...
zurück nach PowerShell** geben:

```csharp
// In C# (kompiliert in Add-Type):
public string ExampleSayHello(string name)
{
    var ex = QueryExample();
    return ex == null ? null : ex.SayHello(name);
}
```

```powershell
# In PowerShell:
Write-Host ($ac.ExampleSayHello("Welt"))
```

### `[ComImport]` mit `IUnknown`-Interfaces

Damit C# die Custom-Interfaces nutzen kann, müssen sie als
`InterfaceType.InterfaceIsIUnknown` deklariert werden, **nicht** als
`InterfaceIsIDispatch` (der Default).

### Kein NativeAOT-Problem

Der Host läuft in normalem .NET Framework / .NET. Die `IReferenceTrackerTarget`-
Falle der NativeAOT-DLLs betrifft uns auf Host-Seite nicht. Wir laden ja keine
.NET-DLLs als unsere DLLs - wir laden native DLLs und greifen nur auf deren
Vtable zu.

## Limitierungen

- Nur Host. Plugins kann man nicht in PowerShell schreiben.
- COM-Objekte können in PowerShell nicht direkt mit Methodenaufrufen verwendet
  werden, daher der C#-Wrapper-Layer.
- Für jedes neue Custom-Interface muss eine entsprechende C#-Wrapper-Methode in
  `AppCentral.ps1` ergänzt werden (siehe `ExampleSayHello`/`ExampleAdd`).

## API-Übersicht

Die in `AppCentral.ps1` enthaltene C#-Klasse hat:

```csharp
public class AppCentral
{
    public bool LoadPlugin(string path);
    public int PluginCount { get; }
    public string PluginFilename(int idx);
    public void Shutdown();

    // Convenience-Methoden für IExample:
    public string ExampleSayHello(string name);
    public int ExampleAdd(int a, int b);
    public string[] AllExamplesSayHello(string name);
}
```

Für eigene Interfaces muss man entsprechende Convenience-Methoden hinzufügen.

## Ausführen

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File C:\Beispiele\AppCentral\Examples\PowerShellHost\main.ps1 `
  -DllPath C:\Beispiele\AppCentral\Output\ExampleDelphiDLL.dll
```

`-ExecutionPolicy Bypass` ist nötig, wenn die Skript-Ausführung in den globalen
Einstellungen restriktiv ist.
