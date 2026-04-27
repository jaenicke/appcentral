/**
 * AppCentral Java host (modernised) - with TryGet, GetAllPlugins, plugin list.
 */
public class Main {

    public static void main(String[] args) {
        System.out.println("=== AppCentral Java host (modernized) ===");
        System.out.println();

        String dllPath = args.length > 0 ? args[0] : "ExampleDelphiDLL.dll";

        AppCentral ac = new AppCentral();

        System.out.println("Loading " + dllPath + "...");
        if (!ac.loadPlugin(dllPath)) {
            System.out.println("ERROR: Could not load plugin");
            return;
        }
        System.out.println("Loaded.");

        if (args.length > 1) {
            if (ac.loadPlugin(args[1]))
                System.out.println("Second plugin loaded: " + args[1]);
        }

        System.out.println();
        System.out.println("--- Plugin list ---");
        for (int i = 0; i < ac.pluginCount(); i++)
            System.out.println("  [" + i + "] " + ac.pluginFilename(i));
        System.out.println();

        // Demo: TryGet
        IExampleProxy example = ac.tryGet(IExampleProxy.IID, IExampleProxy::new);
        if (example != null) {
            System.out.println("IExample.SayHello: " + example.sayHello("World"));
            System.out.println("IExample.Add(3, 4): " + example.add(3, 4));
            example.release();
        } else {
            System.out.println("ERROR: IExample not found!");
        }
        System.out.println();

        // Demo: GetAllPlugins
        var allExamples = ac.getAllPlugins(IExampleProxy.IID, IExampleProxy::new);
        System.out.println("Plugins offering IExample: " + allExamples.size());
        for (int i = 0; i < allExamples.size(); i++) {
            IExampleProxy p = allExamples.get(i);
            System.out.println("  Plugin " + i + ": " + p.sayHello("Plugin"));
            p.release();
        }

        // Demo: Get<T> throws an exception
        System.out.println("\nTesting get<unknown>...");
        // We use a random GUID that's guaranteed not to be registered
        com.sun.jna.platform.win32.Guid.GUID unknownIid =
            new com.sun.jna.platform.win32.Guid.GUID("{DEADBEEF-0000-0000-0000-000000000000}");
        try {
            ac.get(unknownIid, p -> p);
            System.out.println("  -> unexpected: interface found");
        } catch (RuntimeException e) {
            System.out.println("  -> as expected: " + e.getMessage());
        }

        System.out.println();
        System.out.println("Shutdown...");
        ac.shutdown();
        System.out.println("Done.");
    }
}
