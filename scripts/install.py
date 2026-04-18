#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass
from datetime import date
from pathlib import Path


EXCLUDED_DIRS = {
    ".git",
    "node_modules",
    "dist",
    "build",
    ".venv",
    "venv",
    "target",
    "out",
    ".next",
    ".idea",
    ".vscode",
    ".ai",
}

AVAILABLE_PACKS = {"session-state", "jira", "admin-ui-foundation", "video-ops"}
ALWAYS_REQUIRED_PACKS = {"session-state"}
CONDITIONAL_REQUIRED_PACKS = {"admin-ui-foundation"}
ADMIN_UI_BASE_OPTIONS = {"admincore", "custom", "none"}

UI_DIR_HINTS = {"ui", "frontend", "web", "client", "apps", "src"}
SERVER_DIR_HINTS = {"server", "api", "backend", "src", "app"}
SERVICE_DIR_HINTS = {"services", "workers", "jobs", "queues", "consumer", "producer", "scheduler"}


@dataclass
class Stats:
    created_dirs: int = 0
    updated_files: int = 0
    created_files: int = 0
    skipped_files: int = 0


def read_config(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Config not found: {path}")
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def render_template(text: str, tokens: dict[str, str]) -> str:
    out = text
    for k, v in tokens.items():
        out = out.replace(f"{{{{{k}}}}}", v)
    return out


def ensure_dir(path: Path, dry_run: bool, update_only: bool, stats: Stats) -> bool:
    if path.exists():
        return True
    if update_only:
        return False
    if dry_run:
        print(f"[DRY-RUN] mkdir -p {path}")
        stats.created_dirs += 1
        return True
    path.mkdir(parents=True, exist_ok=True)
    stats.created_dirs += 1
    return True


def copy_file(src: Path, dst: Path, dry_run: bool, update_only: bool, stats: Stats) -> None:
    dst_exists = dst.exists()

    if update_only and not dst_exists:
        print(f"[SKIP:update-only] create file blocked: {dst}")
        stats.skipped_files += 1
        return

    if dry_run:
        op = "update" if dst_exists else "create"
        print(f"[DRY-RUN] {op} file: {dst}")
        if dst_exists:
            stats.updated_files += 1
        else:
            stats.created_files += 1
        return

    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    if dst_exists:
        stats.updated_files += 1
    else:
        stats.created_files += 1


def write_text_file(text: str, dst: Path, dry_run: bool, update_only: bool, stats: Stats) -> None:
    dst_exists = dst.exists()

    if update_only and not dst_exists:
        print(f"[SKIP:update-only] create file blocked: {dst}")
        stats.skipped_files += 1
        return

    if dry_run:
        op = "update" if dst_exists else "create"
        print(f"[DRY-RUN] {op} file: {dst}")
        if dst_exists:
            stats.updated_files += 1
        else:
            stats.created_files += 1
        return

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text, encoding="utf-8")
    if dst_exists:
        stats.updated_files += 1
    else:
        stats.created_files += 1


def remove_file(path: Path, dry_run: bool, stats: Stats) -> None:
    if not path.exists():
        return
    if dry_run:
        print(f"[DRY-RUN] delete file: {path}")
        stats.updated_files += 1
        return
    path.unlink()
    stats.updated_files += 1


def rebrand_admincore_text(text: str) -> str:
    return (
        text.replace("PHOENIX", "ADMINCORE")
        .replace("Phoenix", "AdminCore")
        .replace("phoenix", "admincore")
        .replace("Prium", "AdminCore")
        .replace("prium", "admincore")
        .replace("prium.github.io/phoenix", "admincore.local/examples")
    )


def neutralize_html_anchor_hrefs(text: str) -> str:
    anchor_rx = re.compile(r'(<a\b[^>]*?\bhref\s*=\s*")([^"]*)(")', flags=re.IGNORECASE)

    def _replace(match: re.Match[str]) -> str:
        href = match.group(2).strip()
        if href.startswith(("#", "mailto:", "tel:", "javascript:")):
            return match.group(0)
        return f'{match.group(1)}#{match.group(3)}'

    return anchor_rx.sub(_replace, text)


def write_rebranded_text_file(src: Path, dst: Path, dry_run: bool, update_only: bool, stats: Stats) -> None:
    text = src.read_text(encoding="utf-8", errors="ignore")
    text = rebrand_admincore_text(text)
    if src.suffix.lower() in {".html", ".htm"}:
        text = neutralize_html_anchor_hrefs(text)
    write_text_file(text, dst, dry_run=dry_run, update_only=update_only, stats=stats)


def compute_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def find_admin_ui_source_root(root: Path) -> Path | None:
    candidates: list[Path] = []
    if (root / "assets" / "css" / "theme.min.css").exists():
        candidates.append(root)

    for d in root.rglob("*"):
        if not d.is_dir():
            continue
        if (d / "assets" / "css" / "theme.min.css").exists():
            candidates.append(d)
    if not candidates:
        return None
    return sorted(candidates, key=lambda p: len(p.as_posix()))[0]


def resolve_admin_ui_source(
    source_path_raw: str,
    source_url_raw: str,
    source_sha256: str,
    cache_dir_raw: str,
    project_root: Path,
    dry_run: bool,
) -> Path | None:
    if source_path_raw:
        direct = Path(source_path_raw).expanduser()
        if direct.exists():
            return direct.resolve()

    if not source_url_raw:
        return None

    if dry_run:
        print(f"[DRY-RUN] would fetch admin UI source archive from: {source_url_raw}")
        return None

    cache_dir = Path(cache_dir_raw).expanduser() if cache_dir_raw else (project_root / ".tmp" / "admin-ui-cache")
    cache_dir.mkdir(parents=True, exist_ok=True)
    downloads_dir = cache_dir / "downloads"
    extracted_dir = cache_dir / "extracted"
    downloads_dir.mkdir(parents=True, exist_ok=True)
    extracted_dir.mkdir(parents=True, exist_ok=True)

    parsed = urllib.parse.urlparse(source_url_raw)
    is_remote = parsed.scheme in {"http", "https"}

    if is_remote:
        filename = Path(parsed.path).name or "admin-ui-source.zip"
        zip_path = downloads_dir / filename
        print(f"Downloading admin UI archive: {source_url_raw}")
        urllib.request.urlretrieve(source_url_raw, zip_path.as_posix())
    else:
        zip_path = Path(source_url_raw).expanduser()
        if not zip_path.exists():
            raise FileNotFoundError(f"Admin UI source URL/path not found: {source_url_raw}")

    if zip_path.suffix.lower() != ".zip":
        raise ValueError(f"Admin UI source must be a .zip archive: {zip_path}")

    actual_sha = compute_sha256(zip_path)
    if source_sha256:
        expected = source_sha256.strip().lower()
        if actual_sha.lower() != expected:
            raise ValueError(f"Admin UI archive checksum mismatch: expected {expected}, got {actual_sha}")
    print(f"Admin UI archive sha256: {actual_sha}")

    extract_target = extracted_dir / actual_sha
    marker = extract_target / ".extracted-ok"
    if not marker.exists():
        if extract_target.exists():
            shutil.rmtree(extract_target, ignore_errors=True)
        extract_target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(extract_target)
        marker.write_text("ok", encoding="utf-8")

    source_root = find_admin_ui_source_root(extract_target)
    if not source_root:
        raise ValueError(
            "Could not find valid admin UI source root in extracted archive. Expected assets/css/theme.min.css."
        )
    print(f"Admin UI source root: {source_root}")
    return source_root


def copy_dir_files(src_dir: Path, dst_dir: Path, dry_run: bool, update_only: bool, stats: Stats) -> None:
    if not src_dir.exists():
        raise FileNotFoundError(f"Template directory not found: {src_dir}")

    dir_ready = ensure_dir(dst_dir, dry_run=dry_run, update_only=update_only, stats=stats)
    if not dir_ready:
        print(f"[SKIP:update-only] target directory missing: {dst_dir}")
        return

    for item in sorted(src_dir.iterdir(), key=lambda p: p.name):
        if item.is_file():
            copy_file(item, dst_dir / item.name, dry_run=dry_run, update_only=update_only, stats=stats)


def copy_root_markdown_files(src_dir: Path, dst_dir: Path, dry_run: bool, update_only: bool, stats: Stats) -> None:
    if not src_dir.exists():
        return
    dir_ready = ensure_dir(dst_dir, dry_run=dry_run, update_only=update_only, stats=stats)
    if not dir_ready:
        print(f"[SKIP:update-only] target directory missing: {dst_dir}")
        return
    for item in sorted(src_dir.iterdir(), key=lambda p: p.name):
        if item.is_file() and item.suffix.lower() == ".md":
            copy_file(item, dst_dir / item.name, dry_run=dry_run, update_only=update_only, stats=stats)


def copy_tree_files(src_root: Path, dst_root: Path, dry_run: bool, update_only: bool, stats: Stats) -> None:
    if not src_root.exists():
        return
    for item in sorted(src_root.rglob("*"), key=lambda p: str(p).lower()):
        if item.is_file():
            rel = item.relative_to(src_root)
            copy_file(item, dst_root / rel, dry_run=dry_run, update_only=update_only, stats=stats)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Install/update orchestrator templates and optionally analyze a project.",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog=(
            "Commands and examples:\n"
            "  Install only:\n"
            "    python scripts/install.py ./project.config.json\n"
            "\n"
            "  Install + analyze (step 2):\n"
            "    python scripts/install.py ./project.config.json --analyze-project\n"
            "\n"
            "  Analyze only (no template install):\n"
            "    python scripts/install.py ./project.config.json --analyze-project --analyze-only\n"
            "\n"
            "  Dry run:\n"
            "    python scripts/install.py ./project.config.json --dry-run --analyze-project\n"
            "\n"
            "  Force profile:\n"
            "    python scripts/install.py ./project.config.json --analyze-project --analyze-profile node\n"
            "\n"
            "  Enable optional pack:\n"
            "    python scripts/install.py ./project.config.json --analyze-project --enable-pack session-state\n"
            "    python scripts/install.py ./project.config.json --analyze-project --enable-pack session-state,jira\n"
            "    python scripts/install.py ./project.config.json --analyze-project --enable-pack video-ops\n"
            "    python scripts/install.py ./project.config.json --analyze-project --enable-pack admin-ui-foundation --admin-ui-base admincore --admin-ui-source \"D:/Design/admin-ui-source/v1.24.0\"\n"
            "    python scripts/install.py ./project.config.json --analyze-project --enable-pack admin-ui-foundation --admin-ui-source-url \"https://example.com/admin-ui-v1.24.0.zip\" --admin-ui-sha256 \"<sha256>\"\n"
        ),
    )
    parser.add_argument("config_path", nargs="?", default="./project.config.json", help="Path to JSON config file.")
    parser.add_argument("--dry-run", action="store_true", help="Print planned changes without writing files.")
    parser.add_argument(
        "--update-only",
        action="store_true",
        help="Update only existing files. Do not create missing files/directories.",
    )
    parser.add_argument("--analyze-project", action="store_true", help="Scan project and generate overview docs.")
    parser.add_argument("--analyze-only", action="store_true", help="Run analysis only. Skip template installation.")
    parser.add_argument(
        "--module-split-threshold",
        type=int,
        default=12,
        help="Split module details to shared-docs/modules when item count exceeds threshold.",
    )
    parser.add_argument(
        "--analyze-profile",
        choices=["auto", "node", "python", "go", "java", "generic"],
        default="auto",
        help="Analysis profile. auto = detect from project manifests.",
    )
    parser.add_argument(
        "--no-second-step-prompt",
        action="store_true",
        help="Disable post-install prompt for running project analysis.",
    )
    parser.add_argument(
        "--enable-pack",
        default="",
        help="Comma-separated packs to install (supported: session-state, jira, admin-ui-foundation, video-ops). session-state is always auto-enabled.",
    )
    parser.add_argument(
        "--admin-ui-base",
        choices=["admincore", "custom", "none"],
        default="",
        help="Admin UI base mode (default: from config or admincore).",
    )
    parser.add_argument(
        "--admin-ui-source",
        default="",
        help="Optional source path for design examples/assets import (for admin-ui-foundation pack).",
    )
    parser.add_argument(
        "--admin-ui-source-url",
        default="",
        help="Optional URL/path to .zip archive with admin UI source snapshot.",
    )
    parser.add_argument(
        "--admin-ui-sha256",
        default="",
        help="Optional sha256 checksum for admin UI source archive verification.",
    )
    parser.add_argument(
        "--admin-ui-cache-dir",
        default="",
        help="Optional cache dir for downloaded/extracted admin UI archives (default: <projectRoot>/.tmp/admin-ui-cache).",
    )
    return parser.parse_args(argv)


def parse_enabled_packs(config: dict, cli_enable_pack: str) -> list[str]:
    packs: set[str] = set()

    if cli_enable_pack:
        for raw in cli_enable_pack.split(","):
            p = raw.strip().lower()
            if p:
                packs.add(p)

    config_packs = config.get("enabledPacks", [])
    if isinstance(config_packs, str):
        for raw in config_packs.split(","):
            p = raw.strip().lower()
            if p:
                packs.add(p)
    elif isinstance(config_packs, list):
        for raw in config_packs:
            if isinstance(raw, str):
                p = raw.strip().lower()
                if p:
                    packs.add(p)

    unknown = sorted([p for p in packs if p not in AVAILABLE_PACKS])
    if unknown:
        raise ValueError(
            f"Unknown pack(s): {', '.join(unknown)}. Supported packs: {', '.join(sorted(AVAILABLE_PACKS))}"
        )
    return sorted(packs)


def apply_default_required_packs(enabled_packs: list[str], admin_ui_base: str) -> list[str]:
    merged = set(enabled_packs)
    merged.update(ALWAYS_REQUIRED_PACKS)
    if admin_ui_base != "none":
        merged.update(CONDITIONAL_REQUIRED_PACKS)
    return sorted(merged)


def parse_admin_ui_base(config: dict, cli_admin_ui_base: str) -> str:
    candidate = (cli_admin_ui_base or "").strip().lower()
    if not candidate:
        candidate = str(config.get("adminUiBase", "admincore")).strip().lower() or "admincore"
    if candidate not in ADMIN_UI_BASE_OPTIONS:
        raise ValueError(
            f"Unknown admin UI base: {candidate}. Supported: {', '.join(sorted(ADMIN_UI_BASE_OPTIONS))}"
        )
    return candidate


def install_admincore_assets(
    target_docs: Path,
    repo_root: Path,
    admin_ui_base: str,
    admin_ui_source: Path | None,
    dry_run: bool,
    update_only: bool,
    stats: Stats,
) -> None:
    if admin_ui_base != "admincore":
        return

    kit_root = repo_root / "templates" / "packs" / "admin-ui-foundation" / "shared-docs" / "assets" / "admincore"
    if not kit_root.exists():
        return

    bundled_css = kit_root / "css" / "admincore-theme.min.css"
    bundled_user_css = kit_root / "css" / "admincore-user.min.css"
    target_css_dir = target_docs / "assets" / "admincore" / "css"
    ensure_dir(target_css_dir, dry_run=dry_run, update_only=update_only, stats=stats)

    if bundled_css.exists():
        copy_file(bundled_css, target_css_dir / "admincore-theme.min.css", dry_run=dry_run, update_only=update_only, stats=stats)
    if bundled_user_css.exists():
        copy_file(bundled_user_css, target_css_dir / "admincore-user.min.css", dry_run=dry_run, update_only=update_only, stats=stats)

    source_root = admin_ui_source if admin_ui_source else None
    if not source_root or not source_root.exists():
        return

    source_theme = source_root / "assets" / "css" / "theme.min.css"
    source_user = source_root / "assets" / "css" / "user.min.css"
    if source_theme.exists():
        write_rebranded_text_file(
            source_theme,
            target_css_dir / "admincore-theme.min.css",
            dry_run=dry_run,
            update_only=update_only,
            stats=stats,
        )
    if source_user.exists():
        write_rebranded_text_file(
            source_user,
            target_css_dir / "admincore-user.min.css",
            dry_run=dry_run,
            update_only=update_only,
            stats=stats,
        )

    examples_root = target_docs / "assets" / "admincore" / "examples"
    module_roots = [
        source_root / "modules" / "components",
        source_root / "modules" / "forms",
        source_root / "modules" / "tables",
        source_root / "modules" / "echarts",
    ]
    copied_examples: list[str] = []
    for root in module_roots:
        if not root.exists():
            continue
        for item in sorted(root.rglob("*.html"), key=lambda p: str(p).lower()):
            rel = item.relative_to(source_root).as_posix()
            write_rebranded_text_file(
                item,
                examples_root / rel,
                dry_run=dry_run,
                update_only=update_only,
                stats=stats,
            )
            copied_examples.append(rel)

    if copied_examples:
        catalog_lines = [
            "# AdminCore Component Catalog",
            "",
            "Generated from source examples. Use these files as the canonical reference when composing admin UI.",
            "",
            "## Example Files",
            *[f"- `{x}`" for x in copied_examples[:250]],
            "",
        ]
        write_text_file(
            "\n".join(catalog_lines),
            target_docs / "tools" / "ADMINCORE-COMPONENT-CATALOG.md",
            dry_run=dry_run,
            update_only=update_only,
            stats=stats,
        )


def synthesize_commands_doc(
    target_docs: Path,
    enabled_packs: list[str],
    admin_ui_base: str,
    dry_run: bool,
    update_only: bool,
    stats: Stats,
) -> None:
    lines = [
        "# Commands",
        "",
        "Single command reference for orchestrator usage and pack-specific command intents.",
        "",
        "## Orchestrator Presets",
        "1. `strict-default`",
        "   - Work strictly as Orchestrator; read project overview/docs first; delegate all implementation asynchronously.",
        "2. `explore-plan-first`",
        "   - Run Explore-Agent first, then Plan-Agent with phased plan.",
        "3. `hotfix`",
        "   - Keep scope minimal, avoid broad refactors, require compact risk report.",
        "4. `frontend-quality`",
        "   - Route through UI-UX-Agent, validate with UI-Test-Agent, check a11y/responsive/error states.",
        "5. `growth-planning`",
        "   - Start with tracking/measurement, then growth/channel agents, return KPI-first plan.",
        "6. `localization-en-ru-heb`",
        "   - Delegate to Language-Translator-Agent with meaning-preserving localization.",
        "7. `conversation-priority`",
        "   - Keep live user discussion priority over result dumps.",
        "",
    ]

    if "session-state" in enabled_packs:
        lines.extend(
            [
                "## Session-State Commands",
                "- `sessions`: list active sessions",
                "- `close session <name>`: archive session (confirmation required)",
                "- `delete session <name>`: delete session (explicit destructive confirmation required)",
                "",
            ]
        )

    if "jira" in enabled_packs:
        lines.extend(
            [
                "## Jira Commands",
                "- `task <KEY>`: read issue summary/status/criteria",
                "- `set in-progress <KEY>`: move issue to active state",
                "- `comment <KEY>`: post final execution summary/evidence",
                "- `attach evidence <KEY>`: attach screenshots/log references if supported",
                "",
            ]
        )

    if "admin-ui-foundation" in enabled_packs and admin_ui_base != "none":
        lines.extend(
            [
                "## Admin UI Foundation Commands",
                "- `admin-ui examples`: use `.ai/shared-docs/tools/ADMINCORE-COMPONENT-CATALOG.md` as source of truth",
                "- `admin-ui mode`: enforce examples-first and baseline consistency",
                "- `admin-ui validate`: verify no ad-hoc pattern drift from baseline",
                "",
            ]
        )

    if "video-ops" in enabled_packs:
        lines.extend(
            [
                "## Video Ops Commands",
                "- `video tools check`: verify yt-dlp/ffmpeg availability in the current environment",
                "- `video download`: fetch media with quality/subtitle options into a project output folder",
                "- `video trim`: trim with yt-dlp `--download-sections` or ffmpeg `-ss/-to`",
                "- `video convert`: remux/transcode to target format/container",
                "- `video extract-audio`: produce mp3/m4a/wav from source video",
                "",
            ]
        )

    write_text_file(
        "\n".join(lines).rstrip() + "\n",
        target_docs / "COMMANDS.md",
        dry_run=dry_run,
        update_only=update_only,
        stats=stats,
    )

    legacy_files = [
        target_docs / "ORCHESTRATOR-MODES.md",
        target_docs / "QUICK-COMMANDS.md",
        target_docs / "QUICK-COMMANDS-JIRA.md",
    ]
    for f in legacy_files:
        remove_file(f, dry_run=dry_run, stats=stats)


def detect_analysis_profile(data: dict) -> str:
    manifests = data["manifests"]
    if manifests["package.json"]:
        return "node"
    if manifests["pyproject.toml"] or manifests["requirements.txt"]:
        return "python"
    if manifests["go.mod"]:
        return "go"
    if manifests["pom.xml"]:
        return "java"
    return "generic"


def gather_project_data(project_root: Path) -> dict:
    top_dirs = [
        p.name
        for p in sorted(project_root.iterdir(), key=lambda x: x.name.lower())
        if p.is_dir() and p.name not in EXCLUDED_DIRS
    ]

    manifests = {
        "package.json": False,
        "pyproject.toml": False,
        "requirements.txt": False,
        "go.mod": False,
        "Cargo.toml": False,
        "pom.xml": False,
        "Dockerfile": False,
        "docker-compose.yml": False,
        "docker-compose.yaml": False,
        "Makefile": False,
        "README": False,
        "CI": False,
    }

    code_ext = {".js", ".ts", ".tsx", ".jsx", ".py", ".go", ".java", ".kt", ".rs", ".cs", ".php"}
    code_files_count = 0

    package_files: list[Path] = []
    docker_files: list[str] = []
    ci_files: list[str] = []
    docs_md_files: list[str] = []
    docs_md_dirs: set[str] = set()
    service_paths: list[str] = []
    ui_paths: list[str] = []
    server_paths: list[str] = []

    for root, dirs, files in os.walk(project_root):
        dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]

        root_path = Path(root)
        rel_root = root_path.relative_to(project_root)
        rel_root_str = "." if str(rel_root) == "." else str(rel_root).replace("\\", "/")
        parts = [] if rel_root_str == "." else rel_root_str.lower().split("/")

        for f in files:
            file_path = root_path / f
            rel = file_path.relative_to(project_root).as_posix()
            lower_name = f.lower()

            if file_path.suffix.lower() in code_ext:
                code_files_count += 1

            if lower_name == "package.json":
                manifests["package.json"] = True
                if len(package_files) < 20:
                    package_files.append(file_path)
            elif lower_name == "pyproject.toml":
                manifests["pyproject.toml"] = True
            elif lower_name == "requirements.txt":
                manifests["requirements.txt"] = True
            elif lower_name == "go.mod":
                manifests["go.mod"] = True
            elif lower_name == "cargo.toml":
                manifests["Cargo.toml"] = True
            elif lower_name == "pom.xml":
                manifests["pom.xml"] = True
            elif lower_name == "dockerfile":
                manifests["Dockerfile"] = True
                if len(docker_files) < 20:
                    docker_files.append(rel)
            elif lower_name in {"docker-compose.yml", "docker-compose.yaml"}:
                manifests[lower_name] = True
                if len(docker_files) < 20:
                    docker_files.append(rel)
            elif lower_name == "makefile":
                manifests["Makefile"] = True
            elif lower_name.startswith("readme"):
                manifests["README"] = True
            elif ".github/workflows" in rel:
                manifests["CI"] = True
                if len(ci_files) < 20:
                    ci_files.append(rel)

            if lower_name.endswith(".md"):
                if len(docs_md_files) < 80:
                    docs_md_files.append(rel)
                parent = str(Path(rel).parent).replace("\\", "/")
                docs_md_dirs.add("." if parent == "." else parent)

            if any(x in parts for x in SERVICE_DIR_HINTS) and len(service_paths) < 25:
                service_paths.append(rel)
            if any(x in parts for x in UI_DIR_HINTS) and len(ui_paths) < 25 and ("component" in rel.lower() or "pages" in rel.lower() or "src/" in rel):
                ui_paths.append(rel)
            if any(x in parts for x in SERVER_DIR_HINTS) and len(server_paths) < 25 and (
                "route" in rel.lower() or "controller" in rel.lower() or "api" in rel.lower() or "server" in rel.lower()
            ):
                server_paths.append(rel)

    return {
        "top_dirs": top_dirs,
        "manifests": manifests,
        "code_files_count": code_files_count,
        "package_files": package_files,
        "docker_files": docker_files,
        "ci_files": ci_files,
        "docs_md_files": sorted(docs_md_files),
        "docs_md_dirs": sorted(docs_md_dirs),
        "service_paths": sorted(set(service_paths)),
        "ui_paths": sorted(set(ui_paths)),
        "server_paths": sorted(set(server_paths)),
    }


def parse_commands(project_root: Path, package_files: list[Path], profile: str) -> list[str]:
    commands: list[str] = []

    for p in package_files[:10]:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            scripts = data.get("scripts", {})
            rel = p.relative_to(project_root).as_posix()
            if scripts:
                keys = [k for k in ["dev", "start", "build", "test", "lint"] if k in scripts]
                if keys:
                    commands.append(f"npm ({rel}): " + ", ".join([f"npm run {k}" for k in keys]))
        except Exception:
            continue

    if (project_root / "Makefile").exists():
        commands.append("make: inspect targets in Makefile")
    if profile == "python" or (project_root / "pyproject.toml").exists() or (project_root / "requirements.txt").exists():
        commands.append("python: define standard run/test commands")
    if profile == "go" or (project_root / "go.mod").exists():
        commands.append("go: go test ./..., go run ./...")
    if profile == "java" and (project_root / "pom.xml").exists():
        commands.append("java(maven): mvn test, mvn package")
    if profile == "node" and not commands:
        commands.append("node: define npm scripts for dev/build/test")

    return commands


def as_bullets(items: list[str], empty_text: str) -> str:
    if not items:
        return f"- {empty_text}"
    return "\n".join([f"- `{x}`" for x in items])


def build_module_details(title: str, items: list[str], project_name: str) -> str:
    return "\n".join(
        [
            f"# {title}",
            "",
            f"Project: {project_name}",
            f"Updated: {date.today().isoformat()}",
            "",
            "## Findings",
            as_bullets(items, "No findings yet."),
            "",
        ]
    )


def generate_overview(
    project_name: str,
    project_root: Path,
    data: dict,
    commands: list[str],
    split_threshold: int,
    profile: str,
) -> tuple[str, dict[str, str]]:
    manifests = [k for k, v in data["manifests"].items() if v]
    top_dirs = data["top_dirs"][:30]

    ui_items: list[str] = []
    server_items: list[str] = []
    service_items: list[str] = []
    infra_items: list[str] = []
    docs_items: list[str] = []

    for d in top_dirs:
        low = d.lower()
        if low in UI_DIR_HINTS or low in {"dashboard", "frontend", "client"}:
            ui_items.append(f"directory: {d}")
        if low in SERVER_DIR_HINTS:
            server_items.append(f"directory: {d}")
        if low in SERVICE_DIR_HINTS:
            service_items.append(f"directory: {d}")

    ui_items.extend(data["ui_paths"][:20])
    server_items.extend(data["server_paths"][:20])
    service_items.extend(data["service_paths"][:20])
    infra_items.extend(data["docker_files"][:20])
    infra_items.extend(data["ci_files"][:20])
    docs_items.extend(data["docs_md_dirs"][:50])
    docs_items.extend(data["docs_md_files"][:50])

    ui_items = sorted(set(ui_items))
    server_items = sorted(set(server_items))
    service_items = sorted(set(service_items))
    infra_items = sorted(set(infra_items))
    docs_items = sorted(set(docs_items))

    risks: list[str] = []
    if data["code_files_count"] == 0:
        risks.append("Project looks new or empty: no code files detected.")
    if not data["manifests"]["README"]:
        risks.append("README not found.")
    if not commands:
        risks.append("No explicit run/test commands detected.")
    if not data["manifests"]["CI"]:
        risks.append("No CI workflow detected in .github/workflows.")
    if not docs_items:
        risks.append("No markdown documentation folders/files detected.")

    unknowns: list[str] = []
    if not ui_items:
        unknowns.append("UI module not clearly detected.")
    if not server_items:
        unknowns.append("Server/API module not clearly detected.")
    if not service_items:
        unknowns.append("Service/worker module not clearly detected.")
    if not docs_items:
        unknowns.append("Project documentation sources are unclear.")

    module_files: dict[str, str] = {}

    def section_or_link(section_title: str, section_key: str, items: list[str]) -> str:
        if len(items) > split_threshold:
            rel_file = f"modules/{section_key}.md"
            module_files[rel_file] = build_module_details(section_title, items, project_name)
            return "\n".join(
                [
                    f"### {section_title}",
                    "- Summary:",
                    f"  - total findings: {len(items)}",
                    f"  - details: [{rel_file}]({rel_file})",
                ]
            )
        return "\n".join([f"### {section_title}", as_bullets(items, "No findings yet.")])

    bootstrap_notes: list[str] = []
    if data["code_files_count"] == 0:
        bootstrap_notes = [
            "Create base folders (`src/`, `tests/`, `docs/`) for your stack.",
            "Add root README with run/build/test commands.",
            "Define minimal CI workflow in `.github/workflows`.",
            "Run analyzer again after first scaffold commit.",
        ]

    suggested_profile_lines = [
        "- Default: Orchestrator + SC-Agent + CR-Agent",
        "- Add UI-Test-Agent if UI module exists",
        "- Add VALIDATION-Agent for write APIs and schema-heavy backends",
    ]
    if profile == "node":
        suggested_profile_lines = [
            "- Orchestrator + SC-Agent + CR-Agent",
            "- UI-Test-Agent for React/Vue screens",
            "- VALIDATION-Agent for API payload contracts",
        ]
    elif profile == "python":
        suggested_profile_lines = [
            "- Orchestrator + SC-Agent + CR-Agent",
            "- Focus SC-Agent on service modules and tests",
            "- Add UI-Test-Agent only if separate frontend exists",
        ]
    elif profile == "go":
        suggested_profile_lines = [
            "- Orchestrator + SC-Agent + CR-Agent",
            "- Focus SC-Agent on handlers/services and integration tests",
            "- Add VALIDATION-Agent for request validation layers",
        ]
    elif profile == "java":
        suggested_profile_lines = [
            "- Orchestrator + SC-Agent + CR-Agent",
            "- Focus SC-Agent on controllers/services/repositories",
            "- Add UI-Test-Agent only if UI module is present",
        ]

    lines = [
        f"# Project Overview: {project_name}",
        "",
        f"Updated: {date.today().isoformat()}",
        f"Project root: `{project_root.as_posix()}`",
        "",
        "## Project Snapshot",
        f"- Analysis profile: **{profile}**",
        f"- Code files detected: **{data['code_files_count']}**",
        f"- Top-level directories: **{len(top_dirs)}**",
        f"- Manifests detected: {', '.join(manifests) if manifests else 'none'}",
        "",
        "## Repository Map",
        as_bullets(top_dirs, "No top-level directories found."),
        "",
        "## Module Breakdown",
        section_or_link("Docs Intake", "docs", docs_items),
        "",
        section_or_link("UI", "ui", ui_items),
        "",
        section_or_link("Server/API", "server", server_items),
        "",
        section_or_link("Services/Workers", "services", service_items),
        "",
        section_or_link("Infra/CI", "infra", infra_items),
        "",
        "## Run/Test/Build Commands",
        as_bullets(commands, "No commands auto-detected. Add them to README and/or package manifests."),
        "",
        "## Risks",
        as_bullets(risks, "No immediate risks detected."),
        "",
        "## Unknowns",
        as_bullets(unknowns, "No major unknowns detected."),
        "",
        "## Suggested Agent Profile",
        *suggested_profile_lines,
        "",
    ]

    if bootstrap_notes:
        lines.extend(["## New Project Bootstrap Notes", as_bullets(bootstrap_notes, "No bootstrap notes."), ""])

    return "\n".join(lines).rstrip() + "\n", module_files


def run_installation(
    repo_root: Path,
    target_copilot: Path,
    target_agents: Path,
    target_docs: Path,
    tokens: dict[str, str],
    dry_run: bool,
    update_only: bool,
    stats: Stats,
    enabled_packs: list[str],
    admin_ui_base: str,
    admin_ui_source: Path | None,
) -> None:
    ensure_dir(target_copilot, dry_run=dry_run, update_only=update_only, stats=stats)
    ensure_dir(target_agents, dry_run=dry_run, update_only=update_only, stats=stats)
    ensure_dir(target_docs, dry_run=dry_run, update_only=update_only, stats=stats)
    ensure_dir(target_docs / "dev", dry_run=dry_run, update_only=update_only, stats=stats)
    ensure_dir(target_docs / "rules", dry_run=dry_run, update_only=update_only, stats=stats)

    copy_dir_files(repo_root / "templates" / "copilot-config" / "agents", target_agents, dry_run=dry_run, update_only=update_only, stats=stats)
    copy_dir_files(repo_root / "templates" / "shared-docs" / "dev", target_docs / "dev", dry_run=dry_run, update_only=update_only, stats=stats)
    copy_dir_files(repo_root / "templates" / "shared-docs" / "rules", target_docs / "rules", dry_run=dry_run, update_only=update_only, stats=stats)
    copy_root_markdown_files(repo_root / "templates" / "shared-docs", target_docs, dry_run=dry_run, update_only=update_only, stats=stats)

    for pack in enabled_packs:
        pack_root = repo_root / "templates" / "packs" / pack
        if not pack_root.exists():
            continue
        pack_agents = pack_root / "copilot-config" / "agents"
        pack_shared_docs = pack_root / "shared-docs"
        if pack_agents.exists():
            copy_dir_files(pack_agents, target_agents, dry_run=dry_run, update_only=update_only, stats=stats)
        if pack_shared_docs.exists():
            copy_tree_files(pack_shared_docs, target_docs, dry_run=dry_run, update_only=update_only, stats=stats)

    if "admin-ui-foundation" in enabled_packs:
        install_admincore_assets(
            target_docs=target_docs,
            repo_root=repo_root,
            admin_ui_base=admin_ui_base,
            admin_ui_source=admin_ui_source,
            dry_run=dry_run,
            update_only=update_only,
            stats=stats,
        )

    template_path = repo_root / "templates" / "copilot-config" / "copilot-instructions.md"
    rendered = render_template(template_path.read_text(encoding="utf-8"), tokens)
    write_text_file(rendered, target_copilot / "copilot-instructions.md", dry_run=dry_run, update_only=update_only, stats=stats)

    constitution_tpl = repo_root / "templates" / "_render" / "CONSTITUTION.md.tpl"
    quality_tpl = repo_root / "templates" / "_render" / "QUALITY-GATES.md.tpl"
    if constitution_tpl.exists():
        constitution_rendered = render_template(constitution_tpl.read_text(encoding="utf-8"), tokens)
        write_text_file(
            constitution_rendered,
            target_docs / "rules" / "CONSTITUTION.md",
            dry_run=dry_run,
            update_only=update_only,
            stats=stats,
        )
    if quality_tpl.exists():
        quality_rendered = render_template(quality_tpl.read_text(encoding="utf-8"), tokens)
        write_text_file(
            quality_rendered,
            target_docs / "rules" / "QUALITY-GATES.md",
            dry_run=dry_run,
            update_only=update_only,
            stats=stats,
        )

    synthesize_commands_doc(
        target_docs=target_docs,
        enabled_packs=enabled_packs,
        admin_ui_base=admin_ui_base,
        dry_run=dry_run,
        update_only=update_only,
        stats=stats,
    )


def run_analysis(
    project_name: str,
    project_root: Path,
    target_docs: Path,
    split_threshold: int,
    analyze_profile: str,
    dry_run: bool,
    update_only: bool,
    stats: Stats,
) -> None:
    data = gather_project_data(project_root)
    effective_profile = analyze_profile if analyze_profile != "auto" else detect_analysis_profile(data)
    commands = parse_commands(project_root, data["package_files"], effective_profile)
    overview, module_files = generate_overview(
        project_name=project_name,
        project_root=project_root,
        data=data,
        commands=commands,
        split_threshold=split_threshold,
        profile=effective_profile,
    )

    write_text_file(overview, target_docs / "project-overview.md", dry_run=dry_run, update_only=update_only, stats=stats)

    if module_files:
        ensure_dir(target_docs / "modules", dry_run=dry_run, update_only=update_only, stats=stats)
        for rel_path, text in module_files.items():
            write_text_file(text, target_docs / rel_path, dry_run=dry_run, update_only=update_only, stats=stats)

    summary = {
        "projectName": project_name,
        "projectRoot": project_root.as_posix(),
        "analysisProfile": effective_profile,
        "codeFilesCount": data["code_files_count"],
        "topLevelDirectories": len(data["top_dirs"]),
        "manifestsDetected": [k for k, v in data["manifests"].items() if v],
        "moduleItemsCount": {
            "docs": len(data["docs_md_dirs"]) + len(data["docs_md_files"]),
            "ui": len(data["ui_paths"]),
            "server": len(data["server_paths"]),
            "services": len(data["service_paths"]),
            "infra": len(data["docker_files"]) + len(data["ci_files"]),
        },
        "generatedAt": date.today().isoformat(),
    }
    write_text_file(
        json.dumps(summary, indent=2) + "\n",
        target_docs / "analysis-summary.json",
        dry_run=dry_run,
        update_only=update_only,
        stats=stats,
    )


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    config_path = Path(args.config_path)
    repo_root = Path(__file__).resolve().parent.parent
    stats = Stats()

    config = read_config(config_path)
    admin_ui_base = parse_admin_ui_base(config, args.admin_ui_base)
    enabled_packs = parse_enabled_packs(config, args.enable_pack)
    enabled_packs = apply_default_required_packs(enabled_packs, admin_ui_base)

    project_name = config.get("projectName", "").strip()
    project_root_raw = config.get("projectRoot", "").strip()
    codex_home_raw = config.get("codexHome", "").strip()
    main_branch = config.get("mainBranch", "main").strip() or "main"
    task_prefix = config.get("taskPrefix", "TASK").strip() or "TASK"
    auth_provider = config.get("authProvider", "TBD").strip() or "TBD"
    compliance_requirements = config.get("complianceRequirements", "TBD").strip() or "TBD"
    a11y_level = config.get("a11yLevel", "WCAG 2.1 AA").strip() or "WCAG 2.1 AA"
    language = config.get("language", "TBD").strip() or "TBD"
    framework = config.get("framework", "TBD").strip() or "TBD"
    database = config.get("database", "TBD").strip() or "TBD"
    hosting = config.get("hosting", "TBD").strip() or "TBD"
    shared_types_path = config.get("sharedTypesPath", "src/shared/types").strip() or "src/shared/types"
    admin_ui_source_raw = (args.admin_ui_source or str(config.get("adminUiSourcePath", "")).strip())
    admin_ui_source_url = (args.admin_ui_source_url or str(config.get("adminUiSourceUrl", "")).strip())
    admin_ui_sha256 = (args.admin_ui_sha256 or str(config.get("adminUiSourceSha256", "")).strip())
    admin_ui_cache_dir = (args.admin_ui_cache_dir or str(config.get("adminUiCacheDir", "")).strip())

    if not project_name or not project_root_raw:
        raise ValueError("projectName and projectRoot are required")

    project_root = Path(project_root_raw)
    codex_home = Path(codex_home_raw) if codex_home_raw else project_root / ".ai"
    admin_ui_source: Path | None = None
    if "admin-ui-foundation" in enabled_packs and admin_ui_base == "admincore":
        admin_ui_source = resolve_admin_ui_source(
            source_path_raw=admin_ui_source_raw,
            source_url_raw=admin_ui_source_url,
            source_sha256=admin_ui_sha256,
            cache_dir_raw=admin_ui_cache_dir,
            project_root=project_root,
            dry_run=args.dry_run,
        )

    target_copilot = codex_home / "copilot-config"
    target_agents = target_copilot / "agents"
    target_docs = codex_home / "shared-docs"

    print("Mode:")
    print(f"- dry-run: {args.dry_run}")
    print(f"- update-only: {args.update_only}")
    print(f"- analyze-project: {args.analyze_project}")
    print(f"- analyze-only: {args.analyze_only}")
    print(f"- analyze-profile: {args.analyze_profile}")
    print(f"- enabled packs: {', '.join(enabled_packs) if enabled_packs else 'none'}")
    print(f"- admin ui base: {admin_ui_base}")
    print(f"- admin ui source path: {admin_ui_source_raw if admin_ui_source_raw else 'none'}")
    print(f"- admin ui source url: {admin_ui_source_url if admin_ui_source_url else 'none'}")
    print(f"- admin ui source resolved: {admin_ui_source if admin_ui_source else 'none'}")
    print(f"- target codex home: {codex_home}")

    if not args.analyze_only:
        tokens = {
            "PROJECT_NAME": project_name,
            "PROJECT_ROOT": str(project_root).replace("\\", "/"),
            "MAIN_BRANCH": main_branch,
            "TASK_PREFIX": task_prefix,
            "DATE": date.today().isoformat(),
            "AUTH_PROVIDER": auth_provider,
            "COMPLIANCE_REQUIREMENTS": compliance_requirements,
            "A11Y_LEVEL": a11y_level,
            "LANGUAGE": language,
            "FRAMEWORK": framework,
            "DATABASE": database,
            "HOSTING": hosting,
            "SHARED_TYPES_PATH": shared_types_path,
        }
        run_installation(
            repo_root=repo_root,
            target_copilot=target_copilot,
            target_agents=target_agents,
            target_docs=target_docs,
            tokens=tokens,
            dry_run=args.dry_run,
            update_only=args.update_only,
            stats=stats,
            enabled_packs=enabled_packs,
            admin_ui_base=admin_ui_base,
            admin_ui_source=admin_ui_source,
        )

    should_prompt_second_step = (
        not args.no_second_step_prompt
        and not args.analyze_project
        and not args.analyze_only
        and not args.dry_run
    )
    if should_prompt_second_step:
        try:
            answer = input("Run second step now: generate project overview analysis? [y/N]: ").strip().lower()
        except EOFError:
            answer = ""
        if answer in {"y", "yes"}:
            args.analyze_project = True

    if args.analyze_project:
        ensure_dir(target_docs, dry_run=args.dry_run, update_only=args.update_only, stats=stats)
        run_analysis(
            project_name=project_name,
            project_root=project_root,
            target_docs=target_docs,
            split_threshold=max(1, args.module_split_threshold),
            analyze_profile=args.analyze_profile,
            dry_run=args.dry_run,
            update_only=args.update_only,
            stats=stats,
        )

    print("\nDone")
    print(f"Project: {project_name}")
    print(f"Codex Home: {codex_home}")
    print(f"Agents: {target_agents}")
    print(f"Docs: {target_docs}")
    print("Summary:")
    print(f"- dirs created: {stats.created_dirs}")
    print(f"- files created: {stats.created_files}")
    print(f"- files updated: {stats.updated_files}")
    print(f"- files skipped: {stats.skipped_files}")

    if args.dry_run:
        print("\nNo files were changed (dry-run).")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        raise
