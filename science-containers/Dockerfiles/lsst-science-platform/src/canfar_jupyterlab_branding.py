"""Set JupyterLab app_name for CANFAR sciplat sessions.

LabApp.app_name is a plain class attribute in JupyterLab 4.x, not a
configurable trait. Passing --LabApp.app_name=... on the CLI raises
TraitError (via notebook_shim). Importing this module (via a .pth file in
site-packages) brands the Lab before any LabApp instance is created.
"""

from __future__ import annotations


def _brand() -> None:
    try:
        import jupyterlab.labapp as labapp

        labapp.LabApp.app_name = "Rubin Science Notebook"
    except Exception:
        pass


_brand()
