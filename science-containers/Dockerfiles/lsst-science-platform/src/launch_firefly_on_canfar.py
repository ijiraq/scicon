#!/usr/bin/env python3
"""CLI helper: ensure a CANFAR Firefly session and print its connect URL.

Session startup no longer calls this. The JupyterLab canfar_lab_extensions
package exposes the same logic via POST /canfar/firefly/ensure.
"""

from __future__ import annotations

import sys

try:
    from canfar_lab_extensions.firefly_session import FireflySession
except ImportError:
    # Editable/dev fallback when the package is not on PYTHONPATH yet.
    import os
    from pathlib import Path

    try:
        from canfar.sessions import Session
    except Exception as ex:
        if ex.__class__.__name__ == "ConfigResetRequiredError":
            _config_file = Path.home() / ".canfar" / "config.yaml"
            if _config_file.exists():
                _config_file.unlink()
            from canfar.sessions import Session
        else:
            raise

    class FireflySession:  # type: ignore[no-redef]
        def __init__(self) -> None:
            self.session = Session()
            self._url = None

        @property
        def url(self) -> str:
            if self._url is None:
                sessions = self.session.fetch("firefly")
                if not sessions:
                    self.session.create(
                        name=os.environ.get("CANFAR_FIREFLY_NAME", "firefly"),
                        image=os.environ.get(
                            "CANFAR_FIREFLY_IMAGE",
                            "images.canfar.net/skaha/firefly:2025.2",
                        ),
                        kind="firefly",
                    )
                    sessions = self.session.fetch("firefly")
                self._url = sessions[0]["connectURL"]
            return self._url


def main() -> int:
    try:
        print(FireflySession().url)
    except Exception as exc:
        print(f"launch_firefly_on_canfar: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
