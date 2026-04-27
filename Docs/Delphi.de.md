# Delphi

AppCentral für Delphi besteht aus genau **einer** Unit `AppCentral.pas`. Die Unit
wird sowohl im Host als auch in den DLLs eingebunden - der `RegisterHost`-Export
kommt automatisch durch das `exports`-Statement in der Unit.

## Voraussetzungen

- Embarcadero Delphi 11 oder neuer (RAD Studio).
- Build erfolgt über `dcc64.exe` (Win64-Compiler). Der Pfad in
  `Build/build_delphi.bat` zeigt standardmäßig auf
  `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe` und ist anzupassen.

## Einbindung in ein eigenes Projekt

In ein bestehendes Delphi-Projekt einbauen:

1. **`AppCentral.pas`** in den Suchpfad legen (oder im selben Verzeichnis).
2. **`Interfaces.pas`** ebenfalls einbinden, oder eine eigene Unit
   mit den Interface-Deklarationen anlegen. Wichtig: identische GUIDs auf allen
   Seiten.
3. Im Host: `uses AppCentral;` und einfach `LoadPlugin`/`Get<T>`/... aufrufen.
4. In einer DLL: `uses AppCentral;` reicht. `RegisterHost` wird automatisch
   exportiert.

## Beispiel - DLL

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
  Result := 'Hallo, ' + Name + '!';
end;

function TExample.Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

end.
```

## Beispiel - Host

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
  // Wichtig: Interface-Variable in eigener Prozedur, damit sie vor Shutdown
  // freigegeben wird (sonst Crash beim FreeLibrary, weil noch Refs offen).
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

## Wichtige Regeln

### Interfaces müssen `safecall` sein

Im Beispiel-Interface ist `safecall` zwingend, sonst klappt das Cross-Language-
Marshalling nicht. `safecall` mappt in COM auf
`HRESULT funktion(args, out retval)` - das ist die universelle Konvention.

```pascal
IExample = interface(IUnknown)
  ['{A1B2C3D4-...}']
  function SayHello(const Name: WideString): WideString; safecall;  // ✓
  // function SayHello(const Name: WideString): WideString; stdcall; ✗
  // (stdcall + WideString-Return = versteckter out-Parameter, inkompatibel)
end;
```

### Host-Interface-Refs vor Shutdown freigeben

Der häufigste Fehler: ein Interface aus einer geladenen DLL wird in einer
lokalen Variable gehalten, bis das Hauptprogramm endet. Beim
`TAppCentral.Shutdown` wird die DLL entladen - die Referenz zeigt jetzt auf
freigegebenen Speicher. Beim Programmende kommt `IntfClear` und versucht
`Release` aufzurufen → Crash.

Fix: Die Interface-Verwendung in eine eigene Prozedur packen:

```pascal
procedure RunExample;
var
  Example: IExample;
begin
  Example := TAppCentral.Get<IExample>;
  WriteLn(Example.SayHello('Welt'));
end;
// hier ist Example aus dem Scope und freigegeben

begin
  TAppCentral.LoadPlugin('foo.dll');
  RunExample;          // läuft komplett ab
  TAppCentral.Shutdown; // ok, keine offenen Refs mehr
end.
```

### Architekturen

x64 (`dcc64.exe`) wird empfohlen und ist der Default. Mischen mit x86 geht nicht
- alle Komponenten müssen dieselbe Architektur haben.

## API-Übersicht

```pascal
// Registrierung
class procedure Register<T: IInterface>(const Instance: T);
class procedure Register<T: IInterface>(const Factory: TFunc<IInterface, T>);
class procedure Unregister<T: IInterface>;

// Abfrage
class function Get<T: IInterface>: T;                               // wirft EAppCentralInterfaceNotFound
class function Get<T: IInterface>(const Params: IInterface): T;
class function TryGet<T: IInterface>(out AInterface: T): Boolean;
class function TryGet<T: IInterface>(const Params: IInterface; out AInterface: T): Boolean;
class function GetAllPlugins<T: IInterface>: TArray<T>;             // alle Plugins die T anbieten

// Plugin-Verwaltung
class function LoadPlugin(const Filename: string): Boolean;          // mit Filename-Dedup
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

Erzeugt `Output/DelphiHost.exe` und `Output/ExampleDelphiDLL.dll`.

## Java direkt aus Delphi laden

Eine Variante des Delphi-Hosts (`DelphiJavaHost`) lädt Java-Klassen direkt via
JNI - ohne separate DLL. Siehe [Java.md](Java.md) für Details.

```pascal
TJVM.Initialize('C:\Pfad\zu\Class-Dateien');
TAppCentral.Register<IExample>(TJavaExampleAdapter.Create('ExampleImpl'));
// jetzt verfügbar wie ein normales Plugin
```
