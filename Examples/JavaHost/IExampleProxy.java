import com.sun.jna.*;
import com.sun.jna.platform.win32.*;
import com.sun.jna.platform.win32.WTypes.BSTR;
import com.sun.jna.ptr.*;

/**
 * Java proxy for the IExample COM interface.
 * Vtable: [0]QI [1]AddRef [2]Release [3]SayHello [4]Add
 *
 * Delphi-Original (safecall):
 *   function SayHello(const Name: WideString): WideString; safecall;
 *   function Add(A, B: Integer): Integer; safecall;
 * In the COM vtable: HRESULT SayHello(this, BSTR, BSTR*) and HRESULT Add(this, int, int, int*)
 */
public class IExampleProxy {

    public static final Guid.GUID IID =
        new Guid.GUID("{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}");

    private final Pointer comPtr;
    private final Pointer vtable;

    public IExampleProxy(Pointer comPtr) {
        this.comPtr = comPtr;
        this.vtable = comPtr.getPointer(0);
    }

    public String sayHello(String name) {
        long fnAddr = Pointer.nativeValue(vtable.getPointer(3L * Native.POINTER_SIZE));
        Function fn = Function.getFunction(new Pointer(fnAddr), Function.ALT_CONVENTION);

        BSTR bstrName = OleAuto.INSTANCE.SysAllocString(name);
        PointerByReference pResult = new PointerByReference();

        try {
            int hr = fn.invokeInt(new Object[]{comPtr, bstrName.getPointer(), pResult});
            if (hr != 0) {
                throw new RuntimeException(String.format("SayHello fehlgeschlagen: HRESULT=0x%08X", hr));
            }

            Pointer resultPtr = pResult.getValue();
            if (resultPtr == null) return null;

            BSTR resultBstr = new BSTR(resultPtr);
            String result = resultBstr.getValue();
            OleAuto.INSTANCE.SysFreeString(resultBstr);
            return result;
        } finally {
            OleAuto.INSTANCE.SysFreeString(bstrName);
        }
    }

    public int add(int a, int b) {
        long fnAddr = Pointer.nativeValue(vtable.getPointer(4L * Native.POINTER_SIZE));
        Function fn = Function.getFunction(new Pointer(fnAddr), Function.ALT_CONVENTION);

        IntByReference pResult = new IntByReference();
        int hr = fn.invokeInt(new Object[]{comPtr, a, b, pResult});
        if (hr != 0) {
            throw new RuntimeException(String.format("Add fehlgeschlagen: HRESULT=0x%08X", hr));
        }
        return pResult.getValue();
    }

    public void release() {
        long fnAddr = Pointer.nativeValue(vtable.getPointer(2L * Native.POINTER_SIZE));
        Function fn = Function.getFunction(new Pointer(fnAddr), Function.ALT_CONVENTION);
        fn.invokeInt(new Object[]{comPtr});
    }
}
