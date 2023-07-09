How to use
==========
You create a class library and add the [NuGet package DllExport](https://www.nuget.org/packages/DllExport/). A dialog is shown (which you can get again later by calling DllExport.bat from the project's root directory). There you have to choose between x86 and x64, the other options did not work for me.
Then it is important to check both "Use our IL Assembler. Try to fix 0x13 / 0x11 opcodes." and "Rebase System.Object: System.Runtime > mscorlib".
After that you check the "Installed" checkbox and hit "Apply".

In Delphi it is sufficient to add the AppCentral unit, but in C# an additional step is neccessary:
- First you click on menu Project --> Add existing item.
- There you select source\AppCentral.cs, but do NOT click add, but instead hit the arrow beneath and click "Add As Link".
- Then you need to add an exported function, which connects AppCentral to the host:
```
    public static class ClientDemo
    {
        [DllExport("RegisterAppCentralPlugin", CallingConvention = CallingConvention.StdCall)]
        static bool RegisterAppCentralPlugin(IAppCentral host, out IAppCentral client)
        {
            client = AppCentral.RegisterHost(host);
            return true;
        }
    }
```

There you can also register an interface for use out of the host application:
```
            AppCentral.Reg<IClientDemoInterface>(new DemoInterface());
```

After that you should be able to consume interfaces from the host application inside the library as well as the other way round.

Need more help?
---------------
If it does not work or you have other comments (for example regarding this usage info), please don't hesitate to contact me as user jaenicke at https://en.delphipraxis.net/ or by mail:
jaenicke.github@outlook.com