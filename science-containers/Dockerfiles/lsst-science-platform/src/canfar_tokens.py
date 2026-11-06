"""Rubin (Gafaelfawr) token for CANFAR LSST sessions.

The CANFAR session token in /etc/nublado/secrets/token (also ACCESS_TOKEN)
is rejected by data.lsst.cloud. A Rubin token is shown only once in the
browser, so it is pasted here by the user and kept in the home directory.

Notebook::

    from canfar_tokens import login_rubin, rubin_token
    login_rubin()                                   # once
    rubin = RSPDiscovery("rubin-dp2", token=rubin_token())
    butler = Butler("rubin-dp2", collections=["dp2"])

Terminal: ``rubin-login``.
"""

from __future__ import annotations

import os
import sys
from getpass import getpass
from pathlib import Path

__all__ = ["TOKEN_FILE", "login_rubin", "rubin_token"]

TOKEN_FILE = Path.home() / ".config" / "canfar" / "rubin_token"
TOKEN_URL = "https://data.lsst.cloud/settings/tokens"


def _activate(token: str) -> None:
    os.environ["RUBIN_TOKEN"] = token
    # Read by Butler for rubin-* repositories when the Butler is created.
    os.environ["BUTLER_RUBIN_ACCESS_TOKEN"] = token


def login_rubin(token: str | None = None) -> None:
    """Prompt for a Rubin token, save it, and use it in this process.

    Parameters
    ----------
    token
        Token to save. If omitted, prompt for it without echoing.
    """
    if token is None:
        print(
            f"Create a token at {TOKEN_URL} with the read:tap and read:image "
            "scopes, then paste it below."
        )
        token = getpass("Rubin token: ")
    token = token.strip()
    if not token:
        raise ValueError("No Rubin token entered.")

    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(TOKEN_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(token + "\n")
    TOKEN_FILE.chmod(0o600)

    _activate(token)
    print(f"Rubin token saved to {TOKEN_FILE}.")


def rubin_token() -> str:
    """Return the saved Rubin token and set it for Butler in this process.

    The saved file wins over ``RUBIN_TOKEN`` so a later ``rubin-login`` in a
    terminal is picked up by running notebooks.

    Raises
    ------
    RuntimeError
        Raised if no Rubin token has been saved.
    """
    token = ""
    if TOKEN_FILE.is_file():
        token = TOKEN_FILE.read_text().strip()
    token = token or os.environ.get("RUBIN_TOKEN", "").strip()
    if not token:
        raise RuntimeError(
            "No Rubin token saved. Run login_rubin() in a notebook cell or "
            "rubin-login in a terminal."
        )
    _activate(token)
    return token


def main() -> int:
    try:
        login_rubin()
    except (ValueError, KeyboardInterrupt, EOFError) as exc:
        print(f"rubin-login: {exc or 'cancelled'}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
