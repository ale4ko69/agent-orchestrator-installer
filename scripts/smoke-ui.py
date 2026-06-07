#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent


def read_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def post_json(url: str, payload: dict, allow_error: bool = False) -> dict:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        headers={"content-type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
            data["_httpStatus"] = response.status
            return data
    except urllib.error.HTTPError as exc:
        if not allow_error:
            raise
        data = json.loads(exc.read().decode("utf-8"))
        data["_httpStatus"] = exc.code
        return data


def wait_for_health(base_url: str, timeout_seconds: float) -> dict:
    deadline = time.monotonic() + timeout_seconds
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            payload = read_json(f"{base_url}/api/health")
            if payload.get("ok"):
                return payload
        except (OSError, urllib.error.URLError) as exc:
            last_error = exc
        time.sleep(0.25)
    raise RuntimeError(f"UI did not become healthy: {last_error}")


def wait_for_job(base_url: str, job_id: str, timeout_seconds: float) -> dict:
    deadline = time.monotonic() + timeout_seconds
    payload: dict = {}
    while time.monotonic() < deadline:
        payload = read_json(f"{base_url}/api/jobs/{job_id}")
        if payload.get("status") not in {"running", "starting"}:
            return payload
        time.sleep(0.25)
    raise RuntimeError(f"UI job did not finish: {payload}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Smoke-test the local installer web UI.")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host for the temporary UI server.")
    parser.add_argument("--port", type=int, default=8876, help="Bind port for the temporary UI server.")
    parser.add_argument("--config", default="project.config.example.json", help="Config path to validate.")
    parser.add_argument("--timeout", type=float, default=12.0, help="Startup timeout in seconds.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    base_url = f"http://{args.host}:{args.port}"
    proc = subprocess.Popen(
        [sys.executable, str(REPO_ROOT / "scripts" / "ui.py"), "--host", args.host, "--port", str(args.port)],
        cwd=REPO_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        health = wait_for_health(base_url, args.timeout)
        packs = read_json(f"{base_url}/api/packs")
        validate = post_json(f"{base_url}/api/config/validate", {"configPath": args.config})
        loaded_config = post_json(f"{base_url}/api/config/load", {"configPath": args.config})
        draft_config = post_json(
            f"{base_url}/api/config/draft",
            {
                "configPath": args.config,
                "installTargets": "codex",
                "packs": ["jira", "specflow"],
            },
        )
        run = post_json(
            f"{base_url}/api/install/run",
            {
                "configPath": args.config,
                "mode": "check-tools",
                "packs": [],
                "installTargets": "codex",
                "noSecondStepPrompt": True,
            },
        )
        started_job = post_json(
            f"{base_url}/api/install/start",
            {
                "configPath": args.config,
                "mode": "check-tools",
                "packs": [],
                "installTargets": "codex",
                "noSecondStepPrompt": True,
            },
        )
        completed_job = wait_for_job(base_url, str(started_job.get("id")), args.timeout)
        rejected_write = post_json(
            f"{base_url}/api/install/run",
            {
                "configPath": args.config,
                "mode": "install",
                "packs": [],
                "installTargets": "codex",
                "noSecondStepPrompt": True,
            },
            allow_error=True,
        )

        pack_count = len(packs.get("packs", []))
        loaded_summary = loaded_config.get("summary", {})
        draft = draft_config.get("draft", {})
        checks = [
            ("health", bool(health.get("ok"))),
            ("packs", pack_count > 0),
            ("config", bool(validate.get("ok"))),
            (
                "config-load",
                bool(loaded_config.get("ok"))
                and "codex" in loaded_summary.get("installTargets", [])
                and "jira" in loaded_summary.get("enabledPacks", []),
            ),
            (
                "config-draft",
                bool(draft_config.get("ok"))
                and draft.get("installTargets") == ["codex"]
                and draft.get("enabledPacks") == ["jira", "specflow"],
            ),
            ("check-tools", run.get("exitCode") == 0),
            (
                "job-stream",
                bool(started_job.get("id"))
                and completed_job.get("exitCode") == 0
                and "install.py" in str(completed_job.get("output", "")),
            ),
            ("write-gate", rejected_write.get("_httpStatus") == 400 and not rejected_write.get("ok")),
        ]
        for name, ok in checks:
            print(f"{name}: {'ok' if ok else 'failed'}")

        print(f"repoRoot: {health.get('repoRoot', '')}")
        print(f"packs.count: {pack_count}")
        print(f"config.path: {validate.get('path', '')}")
        print(f"config.targets: {','.join(loaded_summary.get('installTargets', []))}")
        print(f"config.packs: {','.join(loaded_summary.get('enabledPacks', []))}")
        print(f"draft.targets: {','.join(draft.get('installTargets', []))}")
        print(f"draft.packs: {','.join(draft.get('enabledPacks', []))}")
        print(f"job.id: {started_job.get('id', '')}")
        print(f"job.exit: {completed_job.get('exitCode', '')}")
        return 0 if all(ok for _, ok in checks) else 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
