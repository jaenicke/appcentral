# FreePascal

🇩🇪 [Deutsche Version](FreePascal.de.md)

AppCentral shares the `AppCentral.pas` unit between Delphi and FreePascal.
Conditional compilation via `{$IFDEF FPC}` toggles the differences.

## Requirements

- **64-bit FreePascal** (`x86_64-win64`).
- Recommended: Lazarus 4.0 64-bit (ships FPC 3.2.2 for x64).
- Default path: `C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe`.

Important: install Lazarus 64-bit, not the 32-bit variant. The Win64
distribution often only ships the i386-win32 compiler — that allows building
32-bit binaries only, which won't interoperate with the rest of AppCentral
(x64).

## Adding it to your own project

The `AppCentral.pas` unit works across both compilers, using `{$IFDEF FPC}`
for FPC-specific tweaks:

```pascal
unit AppCentral;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  SysUtils, Generics.Collections, TypInfo, Windows, ActiveX;
  {$ELSE}
  System.SysUtils, System.Generics.Collections, System.TypInfo,
  Winapi.Windows, Winapi.ActiveX;
  {$ENDIF}
```

To add it to your own project:

1. Include `AppCentral.pas` and `Interfaces.pas`.
2. In the host: `uses AppCentral;` and use the API.
3. In a DLL: `uses AppCentral;` plus `exports RegisterHost;` in the `.lpr`.
   FPC (unlike Delphi) does **not** allow `exports` in a unit — the DLL must
   export it itself.

## Example — DLL

`MyPlugin.lpr`:

```pascal
library MyPlugin;

{$mode delphi}
{$H+}

uses
  AppCentral, Interfaces, MyPlugin.Impl;

exports
  RegisterHost;

begin
  TAppCentral.Register<IExample>(TExample.Create);
end.
```

`MyPlugin.Impl.pas`:

```pascal
unit MyPlugin.Impl;

{$mode delphi}
{$H+}

interface

uses
  SysUtils, Interfaces;

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

Compile:

```
fpc -O2 -B MyPlugin.lpr
```

## Example — host

```pascal
program MyHost;

{$mode delphi}{$H+}{$APPTYPE CONSOLE}

uses
  SysUtils, AppCentral, Interfaces;

procedure RunExample;
var
  Example: IExample;
begin
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

## Differences from Delphi

### `exports` must live in the `.lpr`

Delphi allows `exports` inside a unit. FPC does not — the export has to be
declared in the library main module (`.lpr`):

```pascal
library MyPlugin;
uses AppCentral;
exports RegisterHost;
begin
end.
```

In `AppCentral.pas` the `exports` clause is therefore wrapped in
`{$IFNDEF FPC}`.

### No anonymous methods / `reference to function`

FPC 3.2.2 has **no** `reference to function` closure types. The
`Register<T>(Factory: TFunc<...>)` overload is therefore disabled with
`{$IFNDEF FPC}`. Only the singleton variant `Register<T>(Instance: T)` is
available in FPC.

### No inline `var` declarations

FPC mode delphi doesn't support `for var I := ...`. Use classic declarations:

```pascal
var
  I: Integer;
begin
  for I := 0 to ... do ...
end;
```

### `GetTypeName(TypeInfo(T))` is Delphi-specific

FPC: `string(PTypeInfo(TypeInfo(T))^.Name)`. In `AppCentral.pas` this is
toggled via `{$IFDEF FPC}`.

### Generic methods calling other generics of the same class

FPC 3.2.2 has an internal compiler error when one generic class method calls
another generic class method. `Get<T>` therefore calls `ResolveInterface` and
`Supports` directly, not `TryGet<T>`.

### `TPluginInfo` records with interface fields

In FPC, interface fields inside record types are not always finalized
correctly when only `TList.Clear` is called. So in `Shutdown`, set
`Plugin.Provider := nil;` explicitly before clearing the list.

## API summary

Identical to the Delphi API, with the exceptions above:

```pascal
// Available:
class procedure Register<T: IInterface>(const Instance: T);
class procedure Unregister<T: IInterface>;
class function Get<T: IInterface>: T;
class function Get<T: IInterface>(const Params: IInterface): T;
class function TryGet<T: IInterface>(out AInterface: T): Boolean;
class function TryGet<T: IInterface>(const Params: IInterface; out AInterface: T): Boolean;
class function GetAllPlugins<T: IInterface>: TArray<T>;
class function LoadPlugin(const Filename: string): Boolean;
class function UnloadPlugin(const Filename: string): Boolean;
class function PluginLoaded(const Filename: string): Boolean;
class function PluginCount: Integer;
class function PluginFilename(Index: Integer): string;
class procedure Shutdown;

// NOT available in FPC:
// class procedure Register<T: IInterface>(const Factory: TFunc<IInterface, T>);
```

## Build

```
Build\build_freepascal.bat
```

Produces `Output/FPCHost.exe` and `Output/ExampleFPCDLL.dll`.

The script tries x64 FPC first and falls back to x86 (with a note that only
32-bit interop is then possible).
