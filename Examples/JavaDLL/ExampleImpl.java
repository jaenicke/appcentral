/**
 * Java-Implementierung von IExample.
 * Called by the C bridge (ExampleJavaDLL.c) over JNI.
 */
public class ExampleImpl {

    private String greeting;

    public ExampleImpl() {
        this.greeting = "Hello";
    }

    public ExampleImpl(String greeting) {
        this.greeting = greeting;
    }

    public String sayHello(String name) {
        return greeting + ", " + name + "! (from Java DLL)";
    }

    public int add(int a, int b) {
        return a + b;
    }
}
