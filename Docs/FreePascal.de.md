# FreePascal

AppCentral teilt die `AppCentral.pas`-Unit zwischen Delphi und FreePascal.
Conditional Compilation per `{$IFDEF FPC}` schaltet die Unterschiede um.

## Voraussetzungen

- **64-bit FreePascal** (`x86_64-win64`).
- Empfohlen: Lazarus 4.0 64-bit (enthält FPC 3.2.2 für x64).
- Pfad-Default: `C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe`.

Wichtig: Lazarus 64-bit installieren, nicht die 32-bit-Variante. Die Win64-
Distribution enthält oft nur den i386-win32-Compiler - dann lassen sich nur
32-bit-Binaries bauen, die nicht mit den anderen (x64) AppCentral-Komponenten
interoperieren.

## Einbindung in ein eigenes Projekt

Die `AppCentral.pas`-Unit ist sprachübergreifend - nutzt `{$IFDEF FPC}` für
FPC-spezifische Anpassungen:

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

In ein eigenes Projekt:

1. `AppCentral.pas` und `Interfaces.pas` einbinden.
2. Im Host: `uses AppCentral;` und API verwenden.
3. In einer DLL: `uses AppCentral;` plus `exports RegisterHost;` in der `.lpr`.
   FPC erlaubt (im Gegensatz zu Delphi) **kein** `exports` in einer Unit, daher
   muss die DLL es selbst exportieren.

## Beispiel - DLL

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
  Result := 'Hallo, ' + Name + '!';
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

## Beispiel - Host

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
  WriteLn(Example.SayHello('Welt'));
  WriteLn(Example.Add(3, 4));
end;

begin
  TAppCentral.LoadPlugin('MyPlugin.dll');
  RunExample;
  TAppCentral.Shutdown;
end.
```

## Unterschiede zu Delphi

### `exports` muss in der `.lpr` stehen

Delphi erlaubt `exports` in einer Unit. FPC nicht - der Export muss im
Library-Hauptmodul (`.lpr`) deklariert werden:

```pascal
library MyPlugin;
uses AppCentral;
exports RegisterHost;
begin
end.
```

In der `AppCentral.pas` ist die `exports`-Klausel daher mit
`{$IFNDEF FPC}` umschlossen.

### Keine Anonymen Methoden / `reference to function`

FPC 3.2.2 kennt **keine** `reference to function`-Closure-Typen. Die
`Register<T>(Factory: TFunc<...>)`-Variante ist daher mit `{$IFNDEF FPC}`
ausgeklammert. Nur die Singleton-Variante `Register<T>(Instance: T)` ist in
FPC verfügbar.

### Keine inline `var`-Deklarationen

FPC mode delphi unterstützt keine `for var I := ...`. Klassisch deklarieren:

```pascal
var
  I: Integer;
begin
  for I := 0 to ... do ...
end;
```

### `GetTypeName(TypeInfo(T))` ist Delphi-spezifisch

FPC: `string(PTypeInfo(TypeInfo(T))^.Name)`. In `AppCentral.pas` ist das per
`{$IFDEF FPC}` umgeschaltet.

### Generic-Methoden, die andere Generics derselben Klasse aufrufen

FPC 3.2.2 hat einen Internal Compiler Error wenn eine generische Klassenmethode
eine andere generische Klassenmethode aufruft. `Get<T>` ruft daher direkt
`ResolveInterface` und `Supports` auf, nicht `TryGet<T>`.

### `TPluginInfo`-Records mit Interface-Feldern

In FPC werden Interface-Felder in Record-Typen nicht immer korrekt finalisiert,
wenn nur `TList.Clear` aufgerufen wird. Daher in `Shutdown` explizit
`Plugin.Provider := nil;` setzen, bevor die Liste geleert wird.

## API-Übersicht

Identisch zur Delphi-API, mit den Ausnahmen oben:

```pascal
// Verfügbar:
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

// In FPC NICHT verfügbar:
// class procedure Register<T: IInterface>(const Factory: TFunc<IInterface, T>);
```

## Build

```
Build\build_freepascal.bat
```

Erzeugt `Output/FPCHost.exe` und `Output/ExampleFPCDLL.dll`.

Das Skript versucht zuerst x64-FPC und fällt sonst auf x86 zurück (mit Hinweis,
dass dann nur 32-bit-Interop möglich ist).
