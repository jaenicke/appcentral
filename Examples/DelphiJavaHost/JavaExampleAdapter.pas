unit JavaExampleAdapter;

{
  Adapter that exposes a Java class as an IExample interface in Delphi.
  Wraps the Java class "ExampleImpl" and delegates method calls through JNI.
}

interface

uses
  System.SysUtils, Interfaces, AppCentral.JNI;

type
  TJavaExampleAdapter = class(TInterfacedObject, IExample)
  private
    FJavaObject: jobject;       // Globale Referenz auf ExampleImpl-Instanz
    FMethodSayHello: jmethodID;
    FMethodAdd: jmethodID;
    FClassRef: jclass;
  public
    constructor Create(const ClassName: AnsiString = 'ExampleImpl');
    destructor Destroy; override;

    // IExample
    function SayHello(const Name: WideString): WideString; safecall;
    function Add(A, B: Integer): Integer; safecall;
  end;

implementation

constructor TJavaExampleAdapter.Create(const ClassName: AnsiString);
var
  LocalClass: jclass;
  Ctor: jmethodID;
  LocalObj: jobject;
begin
  inherited Create;

  // Find the Java class
  LocalClass := TJVM.FindClass(ClassName);
  try
    // Global ref so the GC doesn't free the class
    FClassRef := TJVM.NewGlobalRef(LocalClass);
  finally
    TJVM.DeleteLocalRef(LocalClass);
  end;

  // Get constructor and method IDs
  Ctor := TJVM.GetMethodID(FClassRef, '<init>', '()V');
  FMethodSayHello := TJVM.GetMethodID(FClassRef, 'sayHello', '(Ljava/lang/String;)Ljava/lang/String;');
  FMethodAdd := TJVM.GetMethodID(FClassRef, 'add', '(II)I');

  // Create the instance
  LocalObj := TJVM.NewObject(FClassRef, Ctor);
  try
    FJavaObject := TJVM.NewGlobalRef(LocalObj);
  finally
    TJVM.DeleteLocalRef(LocalObj);
  end;
end;

destructor TJavaExampleAdapter.Destroy;
begin
  if TJVM.Env <> nil then
  begin
    TJVM.DeleteGlobalRef(FJavaObject);
    TJVM.DeleteGlobalRef(FClassRef);
  end;
  inherited;
end;

function TJavaExampleAdapter.SayHello(const Name: WideString): WideString;
var
  JName: jstring;
  JResult: jstring;
  Args: array[0..0] of jvalue;
begin
  JName := TJVM.NewJString(Name);
  try
    Args[0].l := JName;
    JResult := jstring(TJVM.CallObjectMethodA(FJavaObject, FMethodSayHello, @Args[0]));
    try
      Result := TJVM.JStringToWide(JResult);
    finally
      TJVM.DeleteLocalRef(JResult);
    end;
  finally
    TJVM.DeleteLocalRef(JName);
  end;
end;

function TJavaExampleAdapter.Add(A, B: Integer): Integer;
var
  Args: array[0..1] of jvalue;
begin
  Args[0].i := A;
  Args[1].i := B;
  Result := TJVM.CallIntMethodA(FJavaObject, FMethodAdd, @Args[0]);
end;

end.
