AppCentral
==========
AppCentral implements communication between DLL libraries and host applications using interfaces. It supports Delphi and C#. At the moment host applications can only be written in Delphi, plugins / libraries in Delphi or C#.

This project is my fourth implementation of this idea. First I implemented it for myself, then for two companies, and now I have written it again from scratch to publish it. So far this is the best implementation.

You find a short usage info here:
[how-to short info](HOWTO.md)

Supported versions of Delphi / C#
---------------------------------
This project was written using Delphi 11 Community Edition and Visual Studio 2022 Community Edition. I used x86 only and .NET 4.8 for the demo, but meanwhile I tested other .NET versions as well. Be sure to have a look into the how-to file, because there are a few possible pitfalls.

Example
-------
Register an interface in Delphi
```
type
  IAppDialogs = interface
  ['{EA3B37D8-5603-42A9-AC5D-5AC9C70E165C}']
    procedure ShowMessage(const AMessage: WideString); safecall;
  end;

  TAppDialogs = class(TInterfacedObject, IAppDialogs)
   public
     procedure ShowMessage(const AMessage: WideString); safecall;
   end;

implementation

{ TAppDialogs }

procedure TAppDialogs.ShowMessage(const AMessage: WideString);
begin
  Vcl.Dialogs.ShowMessage(AMessage);
end;

initialization
  TAppCentral.Reg<IAppDialogs>(TAppDialogs.Create);

finalization
  TAppCentral.Unreg<IAppDialogs>;
```
Fetch this interface inside the host application or in a DLL
```
TAppCentral.Get<IAppDialogs>.ShowMessage('This is a message!');
```
Or using C#
```
if (AppCentral.TryGet<IAppDialogs>(out IAppDialogs Dialogs))
{
  Dialogs.ShowMessage("Message from DLL: C# DLL registered!");
}
```

Plans for the future
--------------------
I would like to <strike>support more .NET versions and I would like to</strike> (done) support C# as a host application. So I plan to implement the full functionality in C# as well.

Other languages are on the list as well.

License
-------
MPL 1.1/GPL 2.0/LGPL 2.1, see LICENSE.md

You would like to contribute?
-----------------------------
You can send your commits as pull requests. This is the easiest way for you since I'll do
the merging if neccessary.

Contact
-------
You can contact me as user jaenicke at https://en.delphipraxis.net/ or by mail:
jaenicke.github@outlook.com

Feel free to write, if you have any comments, feedback or the like.