using System;
using AppCentralLib;

Console.WriteLine("=== AppCentral C# host (modernized) ===");
Console.WriteLine();

string dllPath = args.Length > 0 ? args[0] : "ExampleCSharpDLL.dll";

Console.WriteLine($"Loading {dllPath}...");
if (!TAppCentral.LoadPlugin(dllPath))
{
    Console.WriteLine("ERROR: Could not load plugin");
    return;
}
Console.WriteLine("Loaded.");

if (args.Length > 1)
{
    if (TAppCentral.LoadPlugin(args[1]))
        Console.WriteLine($"Second plugin loaded: {args[1]}");
}

Console.WriteLine();
Console.WriteLine("--- Plugin list ---");
for (int i = 0; i < TAppCentral.PluginCount; i++)
    Console.WriteLine($"  [{i}] {TAppCentral.PluginFilename(i)}");
Console.WriteLine();

void RunExample()
{
    if (TAppCentral.TryGet<IExample>(out var example))
    {
        Console.WriteLine($"IExample.SayHello: {example!.SayHello("World")}");
        Console.WriteLine($"IExample.Add(3, 4): {example.Add(3, 4)}");
    }
    else
    {
        Console.WriteLine("ERROR: IExample not found!");
    }
}

void RunAllPluginsDemo()
{
    var allExamples = TAppCentral.GetAllPlugins<IExample>();
    Console.WriteLine($"Plugins offering IExample: {allExamples.Count}");
    for (int i = 0; i < allExamples.Count; i++)
        Console.WriteLine($"  Plugin {i}: {allExamples[i].SayHello("Plugin")}");
}

RunExample();
Console.WriteLine();
RunAllPluginsDemo();

Console.WriteLine("\nTeste Get<unbekannt>...");
try
{
    var p = TAppCentral.Get<IExampleParams>();
    Console.WriteLine("  -> unexpected: interface found");
}
catch (AppCentralInterfaceNotFoundException e)
{
    Console.WriteLine($"  -> wie erwartet: {e.Message}");
}

Console.WriteLine();
Console.WriteLine("Shutdown...");
TAppCentral.Shutdown();
Console.WriteLine("Done.");
