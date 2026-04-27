# Delphi

🇩🇪 [Deutsche Version](Delphi.de.md)

AppCentral for Delphi consists of a single unit `AppCentral.pas`. The unit is
included in both hosts and DLLs — the `RegisterHost` export is generated
automatically through the `exports` clause in the unit.

## Requirements

- Embarcadero Delphi 11 or newer (RAD Studio).
- Build is done via `dcc64.exe` (Win64 compiler). The path in
  `Build/build_delphi.bat` defaults to
  `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe` and may need
  adjustment.

## Adding it to your own project

To add it to an existing Delphi project:

1. Put **`AppCentral.pas`** in the search path (or the same directory).
2. Include **`Interfaces.pas`** as well, or write your own unit
   with the interface declarations. Important: identical GUIDs on every side.
3. In the host: `uses AppCentral;` and just call `LoadPlugin`/`Get<T>`/...
4. In a DLL: `uses AppCentral;` is enough. `RegisterHost` is exported
   automatically.

## Example — DLL

```pascal
library MyPlugin;

uses
  System.SysUtils,
  AppCentral, Interfaces,
  MyPlugin.Impl in 'MyPlugin.Impl.pas';

begin
  TAppCentral.Register<IExample>(TExample.Create);
end.
```

`MyPlugin.Impl.pas`:

```pascal
unit MyPlugin.Impl;

interface

uses
  System.SysUtils, Interfaces;

type
  TExample = class(TInterfacedObject, IExample)
  public
    function SayHello(const Name: WideString): WideString; safecall;
    function Add(A, B: Integer): Integer; safecall;
  end;

implementation

function TExample.SayHello(const Name: WideString): WideString;
begin
  Result := 'Hello, ' + Name + '!';
end;

function TExample.Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

end.
```

## Example — host

```pascal
program MyHost;
{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AppCentral, Interfaces;

procedure RunExample;
var
  Example: IExample;
begin
  // Important: keep the interface variable in its own procedure so that it
  // is released before Shutdown (otherwise the program crashes during
  // FreeLibrary because there are still open refs).
  Example := TAppCentral.Get<IExample>;
  WriteLn(Example.SayHello('World'));
  WriteLn(Example.Add(3, 4));
end;

begin
  TAppCentral.LoadPlugin('MyPlugin.dll');
  RunExample;
  TAppCentral.Shutdown;
end.
```

## Important rules

### Interfaces must use `safecall`

In the example interface, `safecall` is required — otherwise cross-language
marshaling won't work. `safecall` maps to COM's
`HRESULT function(args, out retval)` — that's the universal convention.

```pascal
IExample = interface(IUnknown)
  ['{A1B2C3D4-...}']
  function SayHello(const Name: WideString): WideString; safecall;  // ✓
  // function SayHello(const Name: WideString): WideString; stdcall; ✗
  // (stdcall + WideString return = hidden out parameter, incompatible)
end;
```

### Release host-side interface refs before Shutdown

The most common bug: an interface from a loaded DLL is held in a local
variable until the main program exits. `TAppCentral.Shutdown` then unloads the
DLL — the reference now points to freed memory. At program termination
`IntfClear` runs and tries to call `Release` → crash.

Fix: wrap the interface usage in its own procedure:

```pascal
procedure RunExample;
var
  Example: IExample;
begin
  Example := TAppCentral.Get<IExample>;
  WriteLn(Example.SayHello('World'));
end;
// here Example is out of scope and released

begin
  TAppCentral.LoadPlugin('foo.dll');
  RunExample;          // runs to completion
  TAppCentral.Shutdown; // ok, no more open refs
end.
```

### Architectures

x64 (`dcc64.exe`) is recommended and the default. Mixing x86 and x64 will not
work — every component must use the same architecture.

## API summary

```pascal
// Registration
class procedure Register<T: IInterface>(const Instance: T);
class procedure Register<T: IInterface>(const Factory: TFunc<IInterface, T>);
class procedure Unregister<T: IInterface>;

// Lookup
class function Get<T: IInterface>: T;                               // throws EAppCentralInterfaceNotFound
class function Get<T: IInterface>(const Params: IInterface): T;
class function TryGet<T: IInterface>(out AInterface: T): Boolean;
class function TryGet<T: IInterface>(const Params: IInterface; out AInterface: T): Boolean;
class function GetAllPlugins<T: IInterface>: TArray<T>;             // every plugin offering T

// Plugin management
class function LoadPlugin(const Filename: string): Boolean;          // with filename de-dup
class function UnloadPlugin(const Filename: string): Boolean;
class function PluginLoaded(const Filename: string): Boolean;
class function PluginCount: Integer;
class function PluginFilename(Index: Integer): string;
class procedure Shutdown;
```

## Build

```
Build\build_delphi.bat
```

Produces `Output/DelphiHost.exe` and `Output/ExampleDelphiDLL.dll`.

## Loading Java directly from Delphi

A Delphi-host variant (`DelphiJavaHost`) loads Java classes directly via JNI
— no separate DLL. See [Java.md](Java.md) for details.

```pascal
TJVM.Initialize('C:\path\to\class\files');
TAppCentral.Register<IExample>(TJavaExampleAdapter.Create('ExampleImpl'));
// now available like a normal plugin
```
