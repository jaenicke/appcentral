unit Interfaces;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

type
  /// <summary>
  /// Sample interface that DLLs register and that hosts query.
  /// Uses safecall for clean COM interop (Delphi <-> C# / Rust / etc.).
  /// </summary>
  IExample = interface(IUnknown)
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function SayHello(const Name: WideString): WideString; safecall;
    function Add(A, B: Integer): Integer; safecall;
  end;

  /// <summary>
  /// Sample parameter interface that can be passed to Get&lt;T&gt;.
  /// </summary>
  IExampleParams = interface(IUnknown)
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function GetGreeting: WideString; safecall;
  end;

implementation

end.
