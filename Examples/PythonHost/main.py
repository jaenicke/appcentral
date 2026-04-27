"""
AppCentral Python host (modernised) - with TryGet, GetAllPlugins, plugin list.
"""

import sys
import os

# app_central.py lives at the AppCentral root (one directory up); add it to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

try:
    import comtypes
except ImportError:
    print("Error: comtypes not installed. Install with 'pip install comtypes'.")
    sys.exit(1)

from app_central import AppCentral, AppCentralInterfaceNotFound
from interfaces import IExample, IExampleParams


def main():
    print("=== AppCentral Python host (modernized) ===")
    print()

    if len(sys.argv) > 1:
        dll_path = sys.argv[1]
    else:
        dll_path = os.path.join(os.path.dirname(__file__), "ExampleDelphiDLL.dll")

    ac = AppCentral()

    print(f"Loading {dll_path}...")
    if not ac.load_plugin(dll_path):
        print("ERROR: Could not load plugin")
        sys.exit(1)
    print("Loaded.")

    if len(sys.argv) > 2:
        if ac.load_plugin(sys.argv[2]):
            print(f"Second plugin loaded: {sys.argv[2]}")

    print()
    print("--- Plugin list ---")
    for i in range(ac.plugin_count()):
        print(f"  [{i}] {ac.plugin_filename(i)}")
    print()

    def run_example():
        # Interface ref only lives inside this function
        example = ac.try_get(IExample)
        if example is not None:
            print(f"IExample.SayHello: {example.SayHello('World')}")
            print(f"IExample.Add(3, 4): {example.Add(3, 4)}")
        else:
            print("ERROR: IExample not found!")

    def run_all_plugins_demo():
        all_examples = ac.get_all_plugins(IExample)
        print(f"Plugins offering IExample: {len(all_examples)}")
        for i, ex in enumerate(all_examples):
            print(f"  Plugin {i}: {ex.SayHello('Plugin')}")

    run_example()
    print()
    run_all_plugins_demo()

    print("\nTeste get<unbekannt>...")
    try:
        ac.get(IExampleParams)
        print("  -> unexpected: interface found")
    except AppCentralInterfaceNotFound as e:
        print(f"  -> wie erwartet: {e}")

    print()
    print("Shutdown...")
    ac.shutdown()
    print("Done.")


if __name__ == "__main__":
    main()
