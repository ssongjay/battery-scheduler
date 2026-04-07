#!/usr/bin/env python3
import os
import sys
from pathlib import Path


def read_text(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def rel(path: str, base: Path) -> str:
    try:
        return str(Path(path).resolve().relative_to(base.resolve()))
    except Exception:
        return path


def summarize_outputs(required_outputs: list[str], run_dir: Path) -> list[str]:
    lines: list[str] = []
    for output in required_outputs:
        output_path = Path(output)
        heading = ""
        try:
            for line in output_path.read_text(encoding="utf-8").splitlines():
                stripped = line.strip()
                if stripped:
                    heading = stripped
                    break
        except Exception:
            heading = ""

        summary = f"- `{rel(str(output_path), run_dir)}`"
        if heading:
            summary += f": {heading[:120]}"
        lines.append(summary)
    return lines


def main() -> int:
    if len(sys.argv) < 10:
      print(
          "usage: write_claude_stage_artifact.py <task-id> <artifact-id> <event-name> "
          "<run-dir> <prompt-file> <response-text> <response-json> <history-log> <output-md> "
          "[required-output...]",
          file=sys.stderr,
      )
      return 1

    task_id, artifact_id, event_name, run_dir_raw, prompt_file, response_text_file, response_json_file, history_file, output_md, *required_outputs = sys.argv[1:]

    run_dir = Path(run_dir_raw)
    brief_path = run_dir / "00-brief.md"
    brief_text = read_text(str(brief_path)) if brief_path.exists() else ""
    prompt_text = read_text(prompt_file)
    response_text = read_text(response_text_file)

    summary_lines = summarize_outputs(required_outputs, run_dir)
    action_items = [
        "- 생성된 canonical output을 검토해 라운드/요약/계약서 내용이 실제로 업데이트되었는지 확인한다.",
        "- 필요하면 Oracle 쪽 대응 파일이나 다음 stage prompt를 갱신한다.",
        "- stage 진행 전 `stage-log.jsonl`과 본 artifact를 함께 보고 흐름을 검증한다.",
    ]

    output_path = Path(output_md)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    content = f"""# Claude Stage Artifact: {artifact_id}

## Task ID

- `{task_id}`

## Event

- `{event_name}`

## Original user task

Source: `{rel(str(brief_path), run_dir)}`

```md
{brief_text.rstrip()}
```

## Final prompt sent to Claude CLI

Source: `{rel(prompt_file, run_dir)}`

```md
{prompt_text.rstrip()}
```

## Claude output (raw)

- text: `{rel(response_text_file, run_dir)}`
- json: `{rel(response_json_file, run_dir)}`
- history: `{rel(history_file, run_dir)}`

```text
{response_text.rstrip()}
```

## Concise summary

- event `{event_name}` completed for artifact `{artifact_id}`.
- canonical outputs refreshed:
{os.linesep.join(summary_lines) if summary_lines else "- 없음"}

## Action items / next steps

{os.linesep.join(action_items)}
"""
    output_path.write_text(content + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
