#!/usr/bin/env python3
import argparse
import json
import mimetypes
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


REPO_ROOT = Path(__file__).resolve().parent.parent
STATIC_ROOT = Path(__file__).resolve().parent / "static"
RUN_MODES = {
    "diff": ["--diff"],
    "dry-run": ["--dry-run"],
    "install": [],
    "update-only": ["--update-only"],
    "analyze-project": ["--analyze-project"],
    "analyze-only": ["--analyze-project", "--analyze-only"],
    "check-tools": ["--check-tools"],
}
REQUIRED_CONFIG_FIELDS = ["projectName", "projectRoot", "codexHome", "projectCodexDir"]


def run_installer(args: list[str]) -> dict[str, object]:
    cmd = [sys.executable, str(REPO_ROOT / "scripts" / "install.py"), *args]
    result = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return {
        "ok": result.returncode == 0,
        "exitCode": result.returncode,
        "command": cmd,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }


def parse_json_body(handler: BaseHTTPRequestHandler) -> dict[str, object]:
    length = int(handler.headers.get("content-length", "0") or "0")
    if length <= 0:
        return {}
    raw = handler.rfile.read(length).decode("utf-8")
    if not raw.strip():
        return {}
    data = json.loads(raw)
    return data if isinstance(data, dict) else {}


def build_pack_args(data: dict[str, object]) -> list[str]:
    packs = data.get("packs", "")
    if isinstance(packs, list):
        packs_arg = ",".join(str(p).strip() for p in packs if str(p).strip())
    else:
        packs_arg = str(packs or "").strip()

    args: list[str] = []
    if packs_arg:
        args.extend(["--enable-pack", packs_arg])
    return args


def build_config_path(data: dict[str, object]) -> str:
    value = str(data.get("configPath") or "project.config.json").strip()
    return value or "project.config.json"


def resolve_config_path(config_path: str) -> Path:
    path = Path(config_path)
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def validate_config(config_path: str) -> dict[str, object]:
    path = resolve_config_path(config_path)
    if not path.exists():
        return {
            "ok": False,
            "path": str(path),
            "error": "Config file does not exist.",
            "missing": REQUIRED_CONFIG_FIELDS,
            "warnings": [],
        }
    if not path.is_file():
        return {"ok": False, "path": str(path), "error": "Config path is not a file.", "warnings": []}

    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {"ok": False, "path": str(path), "error": f"Invalid JSON: {exc}", "warnings": []}

    if not isinstance(config, dict):
        return {"ok": False, "path": str(path), "error": "Config root must be a JSON object.", "warnings": []}

    missing = [field for field in REQUIRED_CONFIG_FIELDS if not config.get(field)]
    warnings: list[str] = []
    install_targets = config.get("installTargets", [])
    if install_targets and not isinstance(install_targets, list):
        warnings.append("installTargets should be an array when set in config.")

    enabled_packs = config.get("enabledPacks", [])
    if enabled_packs and not isinstance(enabled_packs, (list, str)):
        warnings.append("enabledPacks should be an array or comma-separated string.")

    summary = {
        "projectName": config.get("projectName", ""),
        "projectRoot": config.get("projectRoot", ""),
        "installTargets": install_targets,
        "enabledPacks": enabled_packs,
        "adminUiBase": config.get("adminUiBase", ""),
        "adminUiMode": config.get("adminUiMode", ""),
    }
    return {
        "ok": not missing,
        "path": str(path),
        "missing": missing,
        "warnings": warnings,
        "summary": summary,
    }


def build_run_args(data: dict[str, object]) -> list[str]:
    mode = str(data.get("mode") or "diff").strip()
    if mode not in RUN_MODES:
        raise ValueError(f"Unsupported mode: {mode}")

    config_path = build_config_path(data)
    args = [config_path, *build_pack_args(data), *RUN_MODES[mode]]

    targets = str(data.get("installTargets") or "").strip()
    if targets:
        args.extend(["--install-targets", targets])

    if data.get("noSecondStepPrompt", True):
        args.append("--no-second-step-prompt")
    return args


class InstallerUiHandler(BaseHTTPRequestHandler):
    server_version = "AgentInstallerUI/0.1"

    def send_json(self, payload: dict[str, object], status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, text: str, status: int = 200, content_type: str = "text/plain; charset=utf-8") -> None:
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/health":
            self.send_json({"ok": True, "repoRoot": str(REPO_ROOT)})
            return
        if path == "/api/packs":
            result = run_installer(["--list-packs-json"])
            if result["ok"]:
                try:
                    self.send_json(json.loads(str(result["stdout"])))
                except json.JSONDecodeError:
                    self.send_json(result, status=500)
            else:
                self.send_json(result, status=500)
            return
        self.serve_static(path)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        try:
            data = parse_json_body(self)
        except json.JSONDecodeError as exc:
            self.send_json({"ok": False, "error": f"Invalid JSON: {exc}"}, status=400)
            return

        config_path = build_config_path(data)
        pack_args = build_pack_args(data)
        if path == "/api/tools/check":
            result = run_installer([config_path, *pack_args, "--check-tools"])
            self.send_json(result, status=200)
            return
        if path == "/api/install/diff":
            targets = str(data.get("installTargets") or "").strip()
            args = [config_path, *pack_args, "--diff"]
            if targets:
                args.extend(["--install-targets", targets])
            result = run_installer(args)
            self.send_json(result, status=200)
            return
        if path == "/api/config/validate":
            self.send_json(validate_config(config_path), status=200)
            return
        if path == "/api/install/run":
            try:
                args = build_run_args(data)
            except ValueError as exc:
                self.send_json({"ok": False, "error": str(exc)}, status=400)
                return
            self.send_json(run_installer(args), status=200)
            return
        self.send_json({"ok": False, "error": f"Unknown endpoint: {path}"}, status=404)

    def serve_static(self, path: str) -> None:
        rel = "index.html" if path in {"", "/"} else path.lstrip("/")
        target = (STATIC_ROOT / rel).resolve()
        if not str(target).startswith(str(STATIC_ROOT.resolve())) or not target.exists() or not target.is_file():
            self.send_text("Not found", status=404)
            return
        content_type = mimetypes.guess_type(target.name)[0] or "application/octet-stream"
        body = target.read_bytes()
        self.send_response(200)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the local web UI for agent-orchestrator-installer.")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host. Default: 127.0.0.1")
    parser.add_argument("--port", type=int, default=8765, help="Bind port. Default: 8765")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    httpd = ThreadingHTTPServer((args.host, args.port), InstallerUiHandler)
    url = f"http://{args.host}:{args.port}"
    print(f"Agent Orchestrator Installer UI: {url}")
    print("Press Ctrl+C to stop.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
