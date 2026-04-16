#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_commit(repo_root: Path) -> str:
    return subprocess.check_output(["git", "-C", str(repo_root), "rev-parse", "HEAD"], text=True).strip()


def shared_artifacts(protocol_dir: Path) -> list[str]:
    artifacts = [
        "PROTOCOL.md",
        "RUN_GUIDE.md",
        "STAGE_CONTRACTS.md",
        "TEMPLATES.md",
    ]
    for path in sorted((protocol_dir / "scripts").rglob("*")):
        if not path.is_file():
            continue
        if "__pycache__" in path.parts:
            continue
        artifacts.append(str(path.relative_to(protocol_dir)))
    return sorted(artifacts)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol-dir", required=True)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    protocol_dir = Path(args.protocol_dir).resolve()
    repo_root = Path(args.repo_root).resolve()
    output = Path(args.output).resolve()

    artifacts = {rel: sha256(protocol_dir / rel) for rel in shared_artifacts(protocol_dir)}
    payload = {
        "canonical_source": "buy-good-things",
        "canonical_commit": git_commit(repo_root),
        "artifacts": artifacts,
    }
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()

