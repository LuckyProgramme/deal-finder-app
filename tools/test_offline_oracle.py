"""Self-contained tests for fixture isolation; never opens private config."""
import os
from pathlib import Path
import socket
import sys
import unittest
from unittest.mock import patch

from offline_oracle import isolated_oracle_imports, network_disabled


class OracleGuardTests(unittest.TestCase):
    def test_import_environment_is_empty_and_restored(self):
        with patch.dict(os.environ, {"ORACLE_TEST_MARKER": "public-test"}):
            with isolated_oracle_imports():
                self.assertEqual(set(os.environ), {"APPDATA"})
                self.assertEqual(list(Path(os.environ["APPDATA"]).iterdir()), [])
            self.assertEqual(os.environ["ORACLE_TEST_MARKER"], "public-test")

    def test_only_env_file_is_hidden(self):
        with patch.object(Path, "exists", return_value=True):
            with isolated_oracle_imports():
                self.assertFalse(Path(".env").exists())
                self.assertTrue(Path("public-fixture.json").exists())

    def test_preloaded_config_is_refused(self):
        with patch.dict(sys.modules, {"deal_finder.config": object()}):
            with self.assertRaisesRegex(RuntimeError, "fresh Python"):
                with isolated_oracle_imports():
                    self.fail("Must not reuse possibly private configuration")

    def test_network_attempt_is_refused_even_if_oracle_swallows_error(self):
        with self.assertRaisesRegex(RuntimeError, "attempted network"):
            with network_disabled():
                try:
                    socket.create_connection(("example.invalid", 443))
                except RuntimeError:
                    pass

    def test_actual_oracle_import_never_opens_env(self):
        real_read_text = Path.read_text

        def public_read(path, *args, **kwargs):
            if path.name == ".env":
                self.fail("Attempted private .env read")
            return real_read_text(path, *args, **kwargs)

        with patch.object(Path, "read_text", public_read), network_disabled():
            with isolated_oracle_imports():
                import deal_finder.config as config
                self.assertEqual(config.GEMINI_API_KEY, "")
        # This suite intentionally checks the fresh-process restriction too.
        sys.modules.pop("deal_finder.config", None)


if __name__ == "__main__":
    unittest.main()
