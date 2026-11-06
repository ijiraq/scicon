"""Set JupyterLab app_name for CANFAR sciplat sessions.

LabApp.app_name is a plain class attribute in JupyterLab 4.x, not a
configurable trait. Passing --LabApp.app_name=... on the CLI raises
TraitError (via notebook_shim). Importing this module (via a .pth file in
site-packages) brands the Lab before any LabApp instance is created.

The .pth runs in every Python process, and importing jupyterlab.labapp costs
seconds, so the name is set from an import hook only when JupyterLab itself
imports jupyterlab.labapp.
"""

from __future__ import annotations

import sys
from importlib.machinery import PathFinder

_MODULE = "jupyterlab.labapp"
_APP_NAME = "Rubin Science Notebook"


class _BrandOnImport:
    def find_spec(self, fullname, path=None, target=None):
        if fullname != _MODULE:
            return None
        spec = PathFinder.find_spec(fullname, path, target)
        if spec is None or spec.loader is None:
            return spec
        exec_module = spec.loader.exec_module

        def _exec_and_brand(module):
            exec_module(module)
            try:
                module.LabApp.app_name = _APP_NAME
            except Exception:
                pass

        spec.loader.exec_module = _exec_and_brand
        return spec


if not any(isinstance(f, _BrandOnImport) for f in sys.meta_path):
    sys.meta_path.insert(0, _BrandOnImport())
