# PowerShell

🇩🇪 [Deutsche Version](PowerShell.de.md)

PowerShell is supported as a **host only** — PowerShell can't produce native
DLLs.

The implementation is split into two parts: the integration library
`AppCentral.ps1` at the AppCentral root, and the sample driver script
`Examples/PowerShellHost/main.ps1`. The driver dot-sources the library
and uses its `AppCentralPS.AppCentral` class. Because PowerShell
automatically wraps COM objects as `System.__ComObject` (no methods,
late-bound only), all COM logic is encapsulated in C# and compiled at runtime
via `Add-Type`. PowerShell only calls the C# wrapper methods.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+ (both tested).
- .NET Framework (for Windows PS 5.1) or .NET Runtime (for PS 7+).

## Adding it to your project

There's nothing to install — the script is self-contained. Just run it:

```powershell
.\main.ps1 -DllPath C:\path\Plugin.dll [-SecondDllPath ...]
```

## Example — host

Library `AppCentral.ps1` (abbreviated — full version at the AppCentral root):

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

Write-Host ("SayHello: " + $ac.ExampleSayHello("World"))
Write-Host ("Add: " + $ac.ExampleAdd(3, 4))

$ac.Shutdown()
```

## Important rules

### Logic in C#, not in PowerShell

PowerShell wraps COM objects as `System.__ComObject`. These wrappers have no
methods for our custom interfaces — only late-binding via Reflection, which
doesn't work for non-Dispatch interfaces.

Solution: keep all COM calls inside the C# class and only return
**string/int/...** values to PowerShell:

```csharp
// In C# (compiled via Add-Type):
public string ExampleSayHello(string name)
{
    var ex = QueryExample();
    return ex == null ? null : ex.SayHello(name);
}
```

```powershell
# In PowerShell:
Write-Host ($ac.ExampleSayHello("World"))
```

### `[ComImport]` with `IUnknown` interfaces

For C# to use the custom interfaces, they must be declared as
`InterfaceType.InterfaceIsIUnknown`, **not** `InterfaceIsIDispatch` (the
default).

### No NativeAOT problem

The host runs on regular .NET Framework / .NET. The
`IReferenceTrackerTarget` trap from NativeAOT DLLs doesn't affect us on the
host side — we don't load .NET DLLs as our DLLs, we load native DLLs and
only access their vtable.

## Limitations

- Host only. Plugins can't be written in PowerShell.
- COM objects can't be used directly with method calls in PowerShell, hence
  the C# wrapper layer.
- For each new custom interface a corresponding C# wrapper method must be
  added to `AppCentral.ps1` (see `ExampleSayHello`/`ExampleAdd`).

## API summary

The C# class inside `AppCentral.ps1` has:

```csharp
public class AppCentral
{
    public bool LoadPlugin(string path);
    public int PluginCount { get; }
    public string PluginFilename(int idx);
    public void Shutdown();

    // Convenience methods for IExample:
    public string ExampleSayHello(string name);
    public int ExampleAdd(int a, int b);
    public string[] AllExamplesSayHello(string name);
}
```

For your own interfaces, add corresponding convenience methods.

## Run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File C:\Beispiele\AppCentral\Examples\PowerShellHost\main.ps1 `
  -DllPath C:\Beispiele\AppCentral\Output\ExampleDelphiDLL.dll
```

`-ExecutionPolicy Bypass` is needed if script execution is restricted in your
global settings.
