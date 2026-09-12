"""Guards for deterministic fixture generation, never production runtime."""
from contextlib import contextmanager
import os
from pathlib import Path
import socket
import sys
from tempfile import TemporaryDirectory
from unittest.mock import patch


@contextmanager
def isolated_oracle_imports():
    """Import the unchanged oracle without its automatic private .env load."""
    if "deal_finder.config" in sys.modules:
        raise RuntimeError("Run fixture generation in a fresh Python process.")
    real_exists = Path.exists

    def public_exists(path):
        return False if path.name == ".env" else real_exists(path)

    # gspread computes a Windows config directory at import time. Give it an
    # empty temporary directory, never the owner's APPDATA or credentials.
    with TemporaryDirectory(prefix="deal-finder-oracle-") as config_dir:
        with patch.dict(os.environ, {"APPDATA": config_dir}, clear=True), patch.object(Path, "exists", public_exists):
            yield


@contextmanager
def network_disabled():
    attempts = []

    def forbidden(*args, **kwargs):
        attempts.append(True)
        raise RuntimeError("Network is disabled during fixture generation.")

    with patch.object(socket.socket, "connect", forbidden), patch.object(
        socket.socket, "connect_ex", forbidden
    ), patch.object(socket, "create_connection", forbidden):
        yield
    if attempts:
        raise RuntimeError("The oracle attempted network access; fixture export refused.")
