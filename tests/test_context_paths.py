import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ContextPathTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.temp_root = Path(self.temp.name)
        self.home = self.temp_root / "home"
        self.home.mkdir()

    def context_paths(self, cwd, overrides=None):
        env = os.environ.copy()
        env.update({
            "HOME": str(self.home),
            "PYTHONPATH": str(ROOT / "src"),
        })
        for key in ("LAC_DATA_ROOT", "LAC_STATE_ROOT", "AI_MODELS_DIR", "XDG_DATA_HOME", "XDG_STATE_HOME"):
            env.pop(key, None)
        env.update(overrides or {})
        program = (
            "import json; from lac.context import Context; c=Context(); "
            "print(json.dumps({'data':str(c.data_root),'state':str(c.state_root),"
            "'models':str(c.models_root),'catalog':str(c.catalog_cache_root),'repo':c._is_repo}))"
        )
        completed = subprocess.run(
            [sys.executable, "-c", program],
            cwd=str(cwd),
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(completed.stdout)

    def test_checkout_and_unrelated_directory_share_mutable_roots(self):
        unrelated = self.temp_root / "unrelated"
        unrelated.mkdir()
        checkout = self.context_paths(ROOT)
        installed = self.context_paths(unrelated)

        self.assertTrue(checkout["repo"])
        self.assertFalse(installed["repo"])
        for field in ("data", "state", "models", "catalog"):
            self.assertEqual(checkout[field], installed[field])
        self.assertNotEqual(Path(checkout["state"]), ROOT / "state")
        self.assertNotEqual(Path(checkout["models"]), ROOT / "models")

    def test_explicit_mutable_root_overrides_remain_authoritative(self):
        data = self.temp_root / "data"
        state = self.temp_root / "state"
        models = self.temp_root / "weights"
        paths = self.context_paths(ROOT, {
            "LAC_DATA_ROOT": str(data),
            "LAC_STATE_ROOT": str(state),
            "AI_MODELS_DIR": str(models),
        })
        self.assertEqual(paths["data"], str(data))
        self.assertEqual(paths["state"], str(state))
        self.assertEqual(paths["models"], str(models))
        self.assertEqual(paths["catalog"], str(data / "catalog"))


if __name__ == "__main__":
    unittest.main()
