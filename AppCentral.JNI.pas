(*
 * Copyright (c) 2026 Sebastian Jänicke (github.com/jaenicke)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *)
unit AppCentral.JNI;

{
  Minimal JNI bindings for Delphi.

  Allows loading and using Java classes directly from Delphi applications
  without a separate C bridge DLL.

  Usage:
    TJVM.Initialize('C:\path\to\class-files');
    var Env := TJVM.Env;
    var ClassRef := TJVM.FindClass('ExampleImpl');
    ...
    TJVM.Finalize;
}

interface

uses
  Winapi.Windows, System.SysUtils;

type
  jint   = Integer;
  jsize  = Integer;
  jchar  = WideChar;
  jboolean = Byte;

  jobject    = Pointer;
  jclass     = jobject;
  jstring    = jobject;
  jthrowable = jobject;
  jmethodID  = Pointer;
  jfieldID   = Pointer;

  // jvalue union (8 bytes on x64) for NewObjectA / CallXxxMethodA
  Pjvalue = ^jvalue;
  jvalue = packed record
    case Integer of
      0: (z: jboolean);
      1: (i: jint);
      2: (j: Int64);
      3: (f: Single);
      4: (d: Double);
      5: (l: jobject);
  end;

  PJNIEnv = ^PJNINativeInterface;
  PJNINativeInterface = ^TJNINativeInterface;

  PJavaVM = ^PJNIInvokeInterface;
  PJNIInvokeInterface = ^TJNIInvokeInterface;

  // === Function signatures for JNINativeInterface (relevant entries) ===
  TFindClassProc          = function(env: PJNIEnv; name: PAnsiChar): jclass; stdcall;
  TExceptionOccurredProc  = function(env: PJNIEnv): jthrowable; stdcall;
  TExceptionDescribeProc  = procedure(env: PJNIEnv); stdcall;
  TExceptionClearProc     = procedure(env: PJNIEnv); stdcall;
  TNewGlobalRefProc       = function(env: PJNIEnv; obj: jobject): jobject; stdcall;
  TDeleteGlobalRefProc    = procedure(env: PJNIEnv; obj: jobject); stdcall;
  TDeleteLocalRefProc     = procedure(env: PJNIEnv; obj: jobject); stdcall;
  // *A variants have fixed signatures (jvalue array instead of varargs)
  TGetMethodIDProc        = function(env: PJNIEnv; clazz: jclass; name, sig: PAnsiChar): jmethodID; stdcall;
  TNewObjectAProc         = function(env: PJNIEnv; clazz: jclass; methodID: jmethodID; args: Pjvalue): jobject; stdcall;
  TCallObjectMethodAProc  = function(env: PJNIEnv; obj: jobject; methodID: jmethodID; args: Pjvalue): jobject; stdcall;
  TCallIntMethodAProc     = function(env: PJNIEnv; obj: jobject; methodID: jmethodID; args: Pjvalue): jint; stdcall;
  TNewStringProc          = function(env: PJNIEnv; const unicode: PWideChar; len: jsize): jstring; stdcall;
  TGetStringLengthProc    = function(env: PJNIEnv; str: jstring): jsize; stdcall;
  TGetStringCharsProc     = function(env: PJNIEnv; str: jstring; isCopy: PByte): PWideChar; stdcall;
  TReleaseStringCharsProc = procedure(env: PJNIEnv; str: jstring; chars: PWideChar); stdcall;
  TExceptionCheckProc     = function(env: PJNIEnv): jint; stdcall;

  // === JNINativeInterface as a function pointer array ===
  // Instead of a record with named fields we use a simple array of 234
  // function pointers and access them via indices. That avoids problems with
  // Delphi's record layout and the @ operator on procedural-typed fields.
  TJNINativeInterface = array[0..233] of Pointer;

  // === JNIInvokeInterface (JavaVM* vtable) ===
  TDestroyJavaVMProc       = function(vm: PJavaVM): jint; stdcall;
  TAttachCurrentThreadProc = function(vm: PJavaVM; out env: PJNIEnv; args: Pointer): jint; stdcall;
  TDetachCurrentThreadProc = function(vm: PJavaVM): jint; stdcall;
  TGetEnvProc              = function(vm: PJavaVM; out env: PJNIEnv; version: jint): jint; stdcall;

  TJNIInvokeInterface = record
    reserved0, reserved1, reserved2: Pointer;
    DestroyJavaVM:       TDestroyJavaVMProc;
    AttachCurrentThread: TAttachCurrentThreadProc;
    DetachCurrentThread: TDetachCurrentThreadProc;
    GetEnv:              TGetEnvProc;
    AttachCurrentThreadAsDaemon: Pointer;
  end;

  // === JavaVMOption / JavaVMInitArgs ===
  TJavaVMOption = record
    optionString: PAnsiChar;
    extraInfo:    Pointer;
  end;
  PJavaVMOption = ^TJavaVMOption;

  TJavaVMInitArgs = record
    version:            jint;
    nOptions:           jint;
    options:            PJavaVMOption;
    ignoreUnrecognized: jboolean;
  end;

const
  JNI_VERSION_1_8 = $00010008;
  JNI_OK          = 0;
  JNI_EDETACHED   = -2;

type
  TJNI_CreateJavaVM     = function(out vm: PJavaVM; out env: PJNIEnv;
                                   args: Pointer): jint; stdcall;
  TJNI_GetCreatedJavaVMs = function(vmBuf: PPointer; bufLen: jsize;
                                    out nVMs: jsize): jint; stdcall;

// ----------------------------------------------------------------------------
// TJVM - static class for JVM lifecycle management
// ----------------------------------------------------------------------------
type
  TJVM = class
  private
    class var FJVMHandle: HMODULE;
    class var FJVM: PJavaVM;
    class var FEnv: PJNIEnv;
    class var FOwnsJVM: Boolean;
    class procedure LoadJvmDll;
    class function GetFn(Index: Integer): Pointer; static; inline;
  public
    class procedure Initialize(const ClassPath: string);
    class procedure Finalize;

    class property Env: PJNIEnv read FEnv;
    class property VM: PJavaVM read FJVM;

    // --- High-level helper methods ---
    class function FindClass(const Name: AnsiString): jclass;
    class function GetMethodID(Clazz: jclass; const Name, Signature: AnsiString): jmethodID;
    class function NewObject(Clazz: jclass; Ctor: jmethodID): jobject;
    class function CallObjectMethodA(Obj: jobject; MethodID: jmethodID; Args: Pjvalue): jobject;
    class function CallIntMethodA(Obj: jobject; MethodID: jmethodID; Args: Pjvalue): jint;
    class function NewGlobalRef(Obj: jobject): jobject;
    class procedure DeleteGlobalRef(Obj: jobject);
    class procedure DeleteLocalRef(Obj: jobject);

    class function NewJString(const S: WideString): jstring;
    class function JStringToWide(JStr: jstring): WideString;

    class procedure CheckException;
  end;

const
  // Indices in the JNINativeInterface table (see jni.h)
  JNI_FindClass          = 6;
  JNI_ExceptionOccurred  = 15;
  JNI_ExceptionDescribe  = 16;
  JNI_ExceptionClear     = 17;
  JNI_NewGlobalRef       = 21;
  JNI_DeleteGlobalRef    = 22;
  JNI_DeleteLocalRef     = 23;
  JNI_NewObjectA         = 30;
  JNI_GetMethodID        = 33;
  JNI_CallObjectMethodA  = 36;
  JNI_CallIntMethodA     = 51;
  JNI_NewString          = 163;
  JNI_GetStringLength    = 164;
  JNI_GetStringChars     = 165;
  JNI_ReleaseStringChars = 166;
  JNI_ExceptionCheck     = 228;

implementation

uses
  System.IOUtils;

{ TJVM }

class procedure TJVM.LoadJvmDll;
var
  JavaHome, JvmPath: string;
begin
  if FJVMHandle <> 0 then Exit;

  // Load jvm.dll from JAVA_HOME
  JavaHome := GetEnvironmentVariable('JAVA_HOME');
  if JavaHome = '' then
    raise Exception.Create('JAVA_HOME not set');

  JvmPath := TPath.Combine(TPath.Combine(TPath.Combine(JavaHome, 'bin'), 'server'), 'jvm.dll');
  if not FileExists(JvmPath) then
    raise Exception.CreateFmt('jvm.dll not found: %s', [JvmPath]);

  FJVMHandle := LoadLibrary(PChar(JvmPath));
  if FJVMHandle = 0 then
    raise Exception.CreateFmt('could not load jvm.dll: %s', [JvmPath]);
end;

class procedure TJVM.Initialize(const ClassPath: string);
var
  CreateVM: TJNI_CreateJavaVM;
  GetVMs:   TJNI_GetCreatedJavaVMs;
  ExistingVM: PJavaVM;
  NumVMs: jsize;
  Args: TJavaVMInitArgs;
  Opts: array[0..0] of TJavaVMOption;
  ClassPathOpt: AnsiString;
  rc: jint;
begin
  if FJVM <> nil then Exit;

  LoadJvmDll;

  GetVMs := GetProcAddress(FJVMHandle, 'JNI_GetCreatedJavaVMs');
  CreateVM := GetProcAddress(FJVMHandle, 'JNI_CreateJavaVM');

  // Check if a JVM is already running (e.g. because a Java DLL created one)
  rc := GetVMs(@ExistingVM, 1, NumVMs);
  if (rc = JNI_OK) and (NumVMs > 0) then
  begin
    FJVM := ExistingVM;
    rc := FJVM^.GetEnv(FJVM, FEnv, JNI_VERSION_1_8);
    if rc = JNI_EDETACHED then
      rc := FJVM^.AttachCurrentThread(FJVM, FEnv, nil);
    if rc <> JNI_OK then
      raise Exception.CreateFmt('Could not attach to JVM: %d', [rc]);
    FOwnsJVM := False;
    Exit;
  end;

  // Create a new JVM
  ClassPathOpt := AnsiString('-Djava.class.path=' + ClassPath);
  Opts[0].optionString := PAnsiChar(ClassPathOpt);
  Opts[0].extraInfo := nil;

  Args.version := JNI_VERSION_1_8;
  Args.nOptions := 1;
  Args.options := @Opts[0];
  Args.ignoreUnrecognized := 0;

  rc := CreateVM(FJVM, FEnv, @Args);
  if rc <> JNI_OK then
    raise Exception.CreateFmt('Could not create JVM: %d', [rc]);

  FOwnsJVM := True;
end;

class procedure TJVM.Finalize;
begin
  // Don't destroy the JVM - DestroyJavaVM is unstable.
  // If we created it ourselves it lives along with the loader code
  // until process exit. The OS cleans up.
  FJVM := nil;
  FEnv := nil;
end;

class function TJVM.GetFn(Index: Integer): Pointer;
var
  TablePtr: PByte;
begin
  // FEnv: PJNIEnv = ^PJNINativeInterface
  // FEnv^ is PJNINativeInterface = pointer to the first table entry
  TablePtr := PByte(FEnv^);
  Result := PPointer(TablePtr + NativeUInt(Index) * SizeOf(Pointer))^;
end;

class procedure TJVM.CheckException;
var
  Throwable: jthrowable;
  ThrowableClass: jclass;
  GetMessage: jmethodID;
  JMsg: jstring;
  Msg: WideString;
begin
  if TExceptionCheckProc(GetFn(JNI_ExceptionCheck))(FEnv) = 0 then Exit;

  TExceptionDescribeProc(GetFn(JNI_ExceptionDescribe))(FEnv);
  TExceptionClearProc(GetFn(JNI_ExceptionClear))(FEnv);

  Msg := '';
  ThrowableClass := TFindClassProc(GetFn(JNI_FindClass))(FEnv, 'java/lang/Throwable');
  if ThrowableClass <> nil then
  begin
    GetMessage := TGetMethodIDProc(GetFn(JNI_GetMethodID))(FEnv, ThrowableClass,
      'toString', '()Ljava/lang/String;');
    if GetMessage <> nil then
    begin
      JMsg := jstring(TCallObjectMethodAProc(GetFn(JNI_CallObjectMethodA))
        (FEnv, Throwable, GetMessage, nil));
      // Suppress exception during toString
      TExceptionClearProc(GetFn(JNI_ExceptionClear))(FEnv);
      if JMsg <> nil then
      begin
        Msg := JStringToWide(JMsg);
        DeleteLocalRef(JMsg);
      end;
    end;
    DeleteLocalRef(ThrowableClass);
  end;
  DeleteLocalRef(Throwable);

  if Msg = '' then
    raise Exception.Create('Java exception (see stderr for stack trace)')
  else
    raise Exception.Create('Java exception: ' + string(Msg));
end;

class function TJVM.FindClass(const Name: AnsiString): jclass;
begin
  Result := TFindClassProc(GetFn(JNI_FindClass))(FEnv, PAnsiChar(Name));
  if Result = nil then
  begin
    CheckException;
    raise Exception.CreateFmt('Class not found: %s', [string(Name)]);
  end;
end;

class function TJVM.GetMethodID(Clazz: jclass; const Name, Signature: AnsiString): jmethodID;
begin
  Result := TGetMethodIDProc(GetFn(JNI_GetMethodID))
    (FEnv, Clazz, PAnsiChar(Name), PAnsiChar(Signature));
  if Result = nil then
  begin
    CheckException;
    raise Exception.CreateFmt('Method not found: %s%s', [string(Name), string(Signature)]);
  end;
end;

class function TJVM.NewObject(Clazz: jclass; Ctor: jmethodID): jobject;
begin
  Result := TNewObjectAProc(GetFn(JNI_NewObjectA))(FEnv, Clazz, Ctor, nil);
  CheckException;
end;

class function TJVM.CallObjectMethodA(Obj: jobject; MethodID: jmethodID; Args: Pjvalue): jobject;
begin
  Result := TCallObjectMethodAProc(GetFn(JNI_CallObjectMethodA))(FEnv, Obj, MethodID, Args);
  CheckException;
end;

class function TJVM.CallIntMethodA(Obj: jobject; MethodID: jmethodID; Args: Pjvalue): jint;
begin
  Result := TCallIntMethodAProc(GetFn(JNI_CallIntMethodA))(FEnv, Obj, MethodID, Args);
  CheckException;
end;

class function TJVM.NewGlobalRef(Obj: jobject): jobject;
begin
  Result := TNewGlobalRefProc(GetFn(JNI_NewGlobalRef))(FEnv, Obj);
end;

class procedure TJVM.DeleteGlobalRef(Obj: jobject);
begin
  if Obj <> nil then
    TDeleteGlobalRefProc(GetFn(JNI_DeleteGlobalRef))(FEnv, Obj);
end;

class procedure TJVM.DeleteLocalRef(Obj: jobject);
begin
  if Obj <> nil then
    TDeleteLocalRefProc(GetFn(JNI_DeleteLocalRef))(FEnv, Obj);
end;

class function TJVM.NewJString(const S: WideString): jstring;
begin
  if S = '' then
    Result := TNewStringProc(GetFn(JNI_NewString))(FEnv, PWideChar(WideString('')), 0)
  else
    Result := TNewStringProc(GetFn(JNI_NewString))(FEnv, PWideChar(S), Length(S));
end;

class function TJVM.JStringToWide(JStr: jstring): WideString;
var
  Len: jsize;
  Chars: PWideChar;
begin
  if JStr = nil then Exit('');
  Len := TGetStringLengthProc(GetFn(JNI_GetStringLength))(FEnv, JStr);
  Chars := TGetStringCharsProc(GetFn(JNI_GetStringChars))(FEnv, JStr, nil);
  try
    SetString(Result, Chars, Len);
  finally
    TReleaseStringCharsProc(GetFn(JNI_ReleaseStringChars))(FEnv, JStr, Chars);
  end;
end;

end.
