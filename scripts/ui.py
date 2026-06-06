#!/usr/bin/env python3
import sys
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    sys.path.insert(0, str(repo_root))
    from installer_ui.server import main as server_main

    return server_main(sys.argv[1:])


if __name__ == "__main__":
    raise SystemExit(main())
