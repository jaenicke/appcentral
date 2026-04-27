# Python

Python ist nur als **Host** unterstützt - native Plugin-DLLs schreibt man in
Python sinnvoll nicht (man bräuchte Cython, cffi oder ähnliches mit massivem
Overhead). Als Host ist Python aber sehr handlich.

Die Implementation nutzt das `comtypes`-Paket für COM-Interop.

## Voraussetzungen

- Python 3.x (getestet mit 3.14).
- `pip install comtypes` (Version 1.4+).

## Einbindung in ein eigenes Projekt

1. `app_central.py` (Integrations-Bibliothek aus dem AppCentral-Root) und
   `interfaces.py` (eigene Interface-Deklarationen) ins Projekt legen.
2. Eigene Interface-Definitionen in `interfaces.py` (oder eigener Datei) als
   comtypes-Klassen anlegen.

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

Mit `['out', 'retval']` packt comtypes den letzten Out-Parameter automatisch
zum Funktionsrückgabewert um - die Methoden lassen sich dann pythonisch
aufrufen.

## Beispiel - Host

```python
import sys
from app_central import AppCentral, AppCentralInterfaceNotFound
from interfaces import IExample, IExampleParams


def main():
    ac = AppCentral()
    ac.load_plugin(sys.argv[1])

    def run_example():
        # Interface-Referenz lebt nur innerhalb dieser Funktion
        example = ac.try_get(IExample)
        if example is not None:
            print(example.SayHello('Welt'))
            print(example.Add(3, 4))

    run_example()

    # Alle Plugins die IExample anbieten
    all_examples = ac.get_all_plugins(IExample)
    for i, ex in enumerate(all_examples):
        print(f"Plugin {i}: {ex.SayHello('Plugin')}")

    # Get<T> wirft Exception
    try:
        ac.get(IExampleParams)
    except AppCentralInterfaceNotFound as e:
        print(e)

    ac.shutdown()


if __name__ == "__main__":
    main()
```

## Wichtige Regeln

### `safecall`-Methoden in comtypes

Delphi `safecall`-Methoden mappen auf COM `HRESULT funktion(args, out retval)`.
In comtypes:

```python
COMMETHOD([], HRESULT, 'MethodName',
          (['in'], ParamType, 'paramName'),
          (['out', 'retval'], ctypes.POINTER(ReturnType), 'pResult'))
```

Das `'retval'` macht den Out-Parameter zum Funktionsrückgabewert. Pythonisch:

```python
result = example.SayHello('Welt')   # statt: hr = example.SayHello('Welt', byref(result))
```

### IAppCentralProvider hat kein retval

Der Provider verwendet **explizites `HRESULT`** (kein `safecall`/retval), damit
das `FromHost`-Flag und die Out-Parameter direkt sichtbar sind:

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

### Interface-Refs vor Shutdown freigeben

Python verwendet Reference Counting. Eine lokale Variable mit einem COM-Wrapper
wird beim Verlassen des Scopes freigegeben - **dann** wird `Release` auf das
COM-Objekt aufgerufen. Wenn die DLL zu diesem Zeitpunkt schon entladen ist,
crasht es.

Lösung: COM-Verwendung in eine eigene Funktion packen:

```python
def run_example():
    example = ac.try_get(IExample)
    print(example.SayHello('Welt'))
# example ist hier weg

run_example()       # läuft komplett ab
ac.shutdown()       # ok
```

### Loop-Variable-Falle

Python `for x in ...:` lässt `x` nach dem Loop weiter existieren. Wenn `x` ein
COM-Objekt ist, wird die Referenz nicht mit dem Loop-Ende freigegeben. In
`AppCentral.shutdown()` ist das berücksichtigt - dort wird mit
`while self._plugins: ...pop(); del entry` gearbeitet, damit keine
Loop-Variable zurückbleibt.

### Architektur

64-bit Python verwenden, wenn die DLLs x64 sind.

## API-Übersicht

```python
class AppCentral:
    # Registrierung
    def register(self, interface_class, instance)
    def unregister(self, interface_class)

    # Abfrage
    def try_get(self, interface_class, params=None)        # → instance oder None
    def get(self, interface_class, params=None)            # wirft AppCentralInterfaceNotFound
    def get_all_plugins(self, interface_class)             # list

    # Plugin-Verwaltung
    def load_plugin(self, path)                            # bool
    def unload_plugin(self, filename)                      # bool
    def plugin_loaded(self, path)                          # bool
    def plugin_count(self)                                 # int
    def plugin_filename(self, idx)                         # str

    def shutdown()
```

## Build

Es gibt keinen Build-Schritt - Python lädt das Modul direkt:

```bash
cd Examples\PythonHost
python main.py C:\Beispiele\AppCentral\Output\ExampleDelphiDLL.dll
```

Die DLL muss x64 sein, wenn Python x64 ist (Standard).
