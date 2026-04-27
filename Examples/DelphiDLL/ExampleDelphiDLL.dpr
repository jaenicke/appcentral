library ExampleDelphiDLL;

uses
  System.SysUtils,
  AppCentral in '..\..\AppCentral.pas',
  Interfaces in '..\Interfaces.pas',
  ExampleDelphiDLL.Impl in 'ExampleDelphiDLL.Impl.pas';

begin
  // Variant 1: Register a fixed singleton instance.
  TAppCentral.Register<IExample>(TExample.Create);

  // Variant 2 (alternative): parameterless typed factory.
  // Note: distinct method name `RegisterProvider` (not a `Register` overload)
  // so generic overload resolution stays unambiguous.
  //   TAppCentral.RegisterProvider<IExample>(
  //     function: IExample
  //     begin
  //       Result := TExample.Create;
  //     end);

  // Variant 3 (alternative): typed factory with typed parameter.
  // Only useful if callers actually pass a typed Params via
  // Get<IExampleParams, IExample>(SomeParams).
  //   TAppCentral.RegisterProvider<IExampleParams, IExample>(
  //     function(const AParams: IExampleParams): IExample
  //     begin
  //       Result := TExample.Create(AParams.GetGreeting);
  //     end);
end.
