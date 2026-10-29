"""Exercise the notebook source cell with real Git, without Colab or Drive."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


NOTEBOOK = Path(__file__).resolve().parents[1] / "notebooks/project1_colab.ipynb"


class ColabSourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.origin = self.root / "origin"
        self.git("init", "--initial-branch=main", str(self.origin))
        self.git("-C", str(self.origin), "config", "user.name", "Test")
        self.git("-C", str(self.origin), "config", "user.email", "test@example.invalid")
        for name in (
            "backend/requirements-colab.txt",
            "backend/scripts/prepare_classifier_data.py",
            "backend/scripts/train_classifier.py",
        ):
            target = self.origin / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.touch()
        self.git("-C", str(self.origin), "add", ".")
        self.git("-C", str(self.origin), "commit", "-m", "main")
        self.main_sha = self.git("-C", str(self.origin), "rev-parse", "HEAD")
        self.git("-C", str(self.origin), "checkout", "-b", "develop")
        (self.origin / "develop-marker").touch()
        self.git("-C", str(self.origin), "add", ".")
        self.git("-C", str(self.origin), "commit", "-m", "develop")
        self.develop_sha = self.git("-C", str(self.origin), "rev-parse", "HEAD")
        self.git("-C", str(self.origin), "tag", "snapshot")
        self.git("-C", str(self.origin), "checkout", "main")
        nb = json.loads(NOTEBOOK.read_text(encoding="utf-8"))
        self.source = "".join(next(c for c in nb["cells"] if c["id"] == "project1-04")["source"])

    @staticmethod
    def git(*args):
        return subprocess.check_output(["git", *args], text=True, stderr=subprocess.PIPE).strip()

    def context(self, ref="develop", run_id="run", mode="github"):
        run_dir = self.root / "artifacts" / run_id
        run_dir.mkdir(parents=True)
        return dict(
            WORK_ROOT=self.root / "work", RUN_ID=run_id, RUN_DIR=run_dir,
            SOURCE_MODE=mode, REPO_URL=str(self.origin), REPO_REF=ref,
            DRIVE_SOURCE=self.origin, subprocess=subprocess, shutil=shutil,
        )

    def test_branch_tag_and_commit(self):
        for index, (ref, expected) in enumerate((
            ("develop", self.develop_sha), ("main", self.main_sha),
            ("snapshot", self.develop_sha), (self.main_sha, self.main_sha),
            ("origin/develop", self.develop_sha),
        )):
            with self.subTest(ref=ref):
                ctx = self.context(ref, f"run-{index}")
                exec(self.source, ctx)
                self.assertEqual(self.git("-C", str(ctx["REPO_DIR"]), "rev-parse", "HEAD"), expected)
                self.assertEqual((ctx["RUN_DIR"] / "source-commit.txt").read_text().strip(), expected)
                detached = subprocess.run(
                    ["git", "-C", str(ctx["REPO_DIR"]), "symbolic-ref", "-q", "HEAD"],
                    capture_output=True,
                )
                self.assertNotEqual(detached.returncode, 0)

    def test_missing_ref_and_retry(self):
        ctx = self.context("missing-branch")
        with self.assertRaisesRegex(RuntimeError, "Cannot resolve REPO_REF='missing-branch'"):
            exec(self.source, ctx)
        self.assertFalse((ctx["RUN_DIR"] / "source-commit.txt").exists())
        with self.assertRaisesRegex(FileExistsError, "configuration cell again"):
            exec(self.source, ctx)
        exec(self.source, self.context(run_id="retry"))

    def test_clone_error_includes_stderr(self):
        ctx = self.context()
        ctx["REPO_URL"] = str(self.root / "nonexistent")
        with self.assertRaisesRegex(RuntimeError, r"(?s)Git failed .*\n.*fatal:"):
            exec(self.source, ctx)

    def test_drive_snapshot(self):
        ctx = self.context(mode="drive")
        exec(self.source, ctx)
        self.assertFalse((ctx["REPO_DIR"] / ".git").exists())
        self.assertIn("Drive source snapshot", (ctx["RUN_DIR"] / "source-commit.txt").read_text())


if __name__ == "__main__":
    unittest.main()
