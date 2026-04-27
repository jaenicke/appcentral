unit ExampleDelphiDLL.Impl;

interface

uses
  System.SysUtils, Interfaces;

type
  TExample = class(TInterfacedObject, IExample)
  private
    FGreeting: string;
  public
    constructor Create; overload;
    constructor Create(const Greeting: string); overload;
    function SayHello(const Name: WideString): WideString; safecall;
    function Add(A, B: Integer): Integer; safecall;
  end;

implementation

constructor TExample.Create;
begin
  inherited Create;
  FGreeting := 'Hello';
end;

constructor TExample.Create(const Greeting: string);
begin
  inherited Create;
  FGreeting := Greeting;
end;

function TExample.SayHello(const Name: WideString): WideString;
begin
  Result := Format('%s, %s! (from Delphi DLL)', [FGreeting, Name]);
end;

function TExample.Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

end.
