unit ExampleFPCDLL.Impl;

{$mode delphi}
{$H+}

interface

uses
  SysUtils, Interfaces;

type
  TExample = class(TInterfacedObject, IExample)
  private
    FGreeting: string;
  public
    constructor Create;
    function SayHello(const Name: WideString): WideString; safecall;
    function Add(A, B: Integer): Integer; safecall;
  end;

implementation

constructor TExample.Create;
begin
  inherited Create;
  FGreeting := 'Hello';
end;

function TExample.SayHello(const Name: WideString): WideString;
begin
  // Explicit WideString cast suppresses FPC's implicit AnsiString->WideString
  // warning (Format returns string = AnsiString in default FPC mode).
  Result := WideString(Format('%s, %s! (from FreePascal DLL)',
    [FGreeting, string(Name)]));
end;

function TExample.Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

end.
