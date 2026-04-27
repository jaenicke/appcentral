# Python

🇩🇪 [Deutsche Version](Python.de.md)

Python is supported as a **host only** — it doesn't make sense to write a
native plugin DLL in Python (you'd need Cython, cffi, or similar with
significant overhead). As a host, however, Python is very convenient.

The implementation uses the `comtypes` package for COM interop.

## Requirements

- Python 3.x (tested with 3.14).
- `pip install comtypes` (version 1.4+).

## Adding it to your own project

1. Drop `app_central.py` (the integration library at the AppCentral root)
   and `interfaces.py` (your interface declarations) into your project.
2. Define your own interfaces in `interfaces.py` (or your own file) as
   comtypes classes.

`interfaces.py`:

```python
import ctypes
import comtypes
from comtypes import GUID, HRESULT, COMMETHOD, BSTR, IUnknown


class IExample(IUnknown):
    _iid_ = GUID('{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}')
    _methods_ = [
        COMMETHOD([], HRESULT, 'SayHello',
                  (['in'], BSTR, 'name'),
                  (['out', 'retval'], ctypes.POINTER(BSTR), 'pResult')),
        COMMETHOD([], HRESULT, 'Add',
                  (['in'], ctypes.c_int, 'a'),
                  (['in'], ctypes.c_int, 'b'),
                  (['out', 'retval'], ctypes.POINTER(ctypes.c_int), 'pResult')),
    ]
```

With `['out', 'retval']` comtypes wraps the last out parameter as the
function return value — methods can then be called the Pythonic way.

## Example — host

```python
import sys
from app_central import AppCentral, AppCentralInterfaceNotFound
from interfaces import IExample, IExampleParams


def main():
    ac = AppCentral()
    ac.load_plugin(sys.argv[1])

    def run_example():
        # Interface ref lives only inside this function
        example = ac.try_get(IExample)
        if example is not None:
            print(example.SayHello('World'))
            print(example.Add(3, 4))

    run_example()

    # All plugins offering IExample
    all_examples = ac.get_all_plugins(IExample)
    for i, ex in enumerate(all_examples):
        print(f"Plugin {i}: {ex.SayHello('Plugin')}")

    # Get<T> throws
    try:
        ac.get(IExampleParams)
    except AppCentralInterfaceNotFound as e:
        print(e)

    ac.shutdown()


if __name__ == "__main__":
    main()
```

## Important rules

### `safecall` methods in comtypes

Delphi `safecall` methods map to COM
`HRESULT function(args, out retval)`. In comtypes:

```python
COMMETHOD([], HRESULT, 'MethodName',
          (['in'], ParamType, 'paramName'),
          (['out', 'retval'], ctypes.POINTER(ReturnType), 'pResult'))
```

The `'retval'` makes the out parameter the function return value. Pythonic:

```python
result = example.SayHello('World')   # instead of: hr = example.SayHello('World', byref(result))
```

### IAppCentralProvider has no retval

The provider uses **explicit `HRESULT`** (no `safecall`/retval), so the
`FromHost` flag and out parameters are visible directly:

```python
IAppCentralProvider._methods_ = [
    COMMETHOD([], HRESULT, 'GetInterface',
              (['in'], ctypes.c_int32, 'fromHost'),
              (['in'], ctypes.POINTER(GUID), 'riid'),
              (['in'], ctypes.POINTER(IUnknown), 'pParams'),
              (['out'], ctypes.POINTER(ctypes.POINTER(IUnknown)), 'ppObj')),
    COMMETHOD([], HRESULT, 'Shutdown'),
]
```

### Release interface refs before Shutdown

Python uses reference counting. A local variable holding a COM wrapper is
released on scope exit — **then** `Release` is called on the COM object. If
the DLL has already been unloaded at that point, you'll get a crash.

Fix: keep COM usage inside its own function:

```python
def run_example():
    example = ac.try_get(IExample)
    print(example.SayHello('World'))
# example is gone here

run_example()       # runs to completion
ac.shutdown()       # ok
```

### Loop variable trap

Python's `for x in ...:` keeps `x` alive after the loop. If `x` is a COM
object, the reference is not released at loop end. In `AppCentral.shutdown()`
this is handled — there we use `while self._plugins: ...pop(); del entry` so
no leftover loop variable remains.

### Architecture

Use 64-bit Python when the DLLs are x64.

## API summary

```python
class AppCentral:
    # Registration
    def register(self, interface_class, instance)
    def unregister(self, interface_class)

    # Lookup
    def try_get(self, interface_class, params=None)        # → instance or None
    def get(self, interface_class, params=None)            # throws AppCentralInterfaceNotFound
    def get_all_plugins(self, interface_class)             # list

    # Plugin management
    def load_plugin(self, path)                            # bool
    def unload_plugin(self, filename)                      # bool
    def plugin_loaded(self, path)                          # bool
    def plugin_count(self)                                 # int
    def plugin_filename(self, idx)                         # str

    def shutdown()
```

## Build

There's no build step — Python loads the module directly:

```bash
cd Examples\PythonHost
python main.py C:\Beispiele\AppCentral\Output\ExampleDelphiDLL.dll
```

The DLL must be x64 if Python is x64 (the default).
