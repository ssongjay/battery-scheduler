#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional


ROOT = Path(__file__).resolve().parents[2]
CANONICAL_RUNS = ROOT / ".protocol" / "runs"
LEGACY_RUNS = ROOT / ".claude" / "session-management" / "runs"

SEVERITIES = ("critical", "high", "medium", "low")
REVIEW_TYPES = ("code", "security", "architecture")
FINDING_CATEGORIES = (
    "missing_requirement",
    "wrong_behavior",
    "out_of_scope_change",
    "contract_violation",
    "test_gap",
    "security_gap",
    "architecture_issue",
)
PROFILE_DIMENSIONS = (
    "abstraction_level",
    "risk_posture",
    "evidence_orientation",
    "execution_bias",
    "adaptability",
)
COMPARATIVE_DIMENSIONS = (
    "problem_framing",
    "bottleneck_identification",
    "guardrail_design",
    "convergence_driving",
)


def append_note_sample(
    samples: List[dict],
    *,
    task_id: str,
    stage: str,
    actor: str,
    model: str,
    notes: str,
) -> None:
    note_text = (notes or "").strip()
    if not note_text:
        return
    samples.append(
        {
            "task_id": task_id,
            "stage": stage,
            "actor": actor,
            "model": model,
            "notes": note_text,
        }
    )


def count_bullets(text: str) -> int:
    return sum(1 for line in text.splitlines() if line.strip().startswith("- "))


def section_text(markdown: str, heading: str) -> str:
    pattern = re.compile(
        rf"(?ms)^{re.escape(heading)}\s*$\n(.*?)(?=^## |\Z)"
    )
    match = pattern.search(markdown)
    return match.group(1).strip() if match else ""


def level_section_text(markdown: str, heading: str) -> str:
    pattern = re.compile(
        rf"(?ms)^{re.escape(heading)}\s*$\n(.*?)(?=^## |\Z)"
    )
    match = pattern.search(markdown)
    return match.group(1).strip() if match else ""


def parse_markdown_sections(markdown: str, headings: Iterable[str]) -> Dict[str, str]:
    return {heading: section_text(markdown, heading) for heading in headings}


def load_json(path: Path) -> Optional[dict]:
    if not path.is_file():
        return None
    return json.loads(path.read_text())


def read_text(path: Path) -> str:
    return path.read_text() if path.is_file() else ""


def extract_release_decision(text: str) -> str:
    lowered = text.lower()
    if "reject" in lowered or "반려" in text or "거부" in text:
        return "reject"
    if "hold" in lowered or "보류" in text:
        return "hold"
    if "approve" in lowered or "승인" in text or "merge 가능한 수준" in text or "merge 가능" in text:
        return "approve"
    return "unknown"


def empty_severity_counter() -> Dict[str, int]:
    return {severity: 0 for severity in SEVERITIES}


def empty_category_counter() -> Dict[str, int]:
    return {category: 0 for category in FINDING_CATEGORIES}


def canonical_stage_counts(stage_log_path: Path) -> Counter:
    counts: Counter = Counter()
    if not stage_log_path.is_file():
        return counts
    for line in stage_log_path.read_text().splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("event") == "stage_complete":
            counts[entry.get("stage", "unknown")] += 1
    return counts


def aggregate_canonical_runs() -> dict:
    runs_total = 0
    by_intent = Counter()
    by_starter = Counter()
    stage_complete_counts = Counter()
    model_pairs = Counter()
    oracle_models = Counter()
    sisyphus_models = Counter()

    debate_runs_total = 0
    debate_issue_count = 0
    debate_overall = Counter()
    debate_issue_verdicts = Counter()
    debate_issue_statuses = Counter()
    debate_adopted_true = 0
    debate_by_pair = defaultdict(Counter)
    debate_meta_runs_total = 0
    debate_meta_evaluators = Counter()
    debate_meta_evaluator_models = Counter()
    debate_meta_oracle_profiles = {
        dimension: Counter() for dimension in PROFILE_DIMENSIONS
    }
    debate_meta_sisyphus_profiles = {
        dimension: Counter() for dimension in PROFILE_DIMENSIONS
    }
    debate_meta_comparative = {
        dimension: Counter() for dimension in COMPARATIVE_DIMENSIONS
    }
    debate_meta_note_samples = []

    review1_runs_total = 0
    review1_findings = {review_type: empty_severity_counter() for review_type in REVIEW_TYPES}
    review1_total_findings = Counter()
    review1_part_totals = Counter()
    review1_implementer_mistakes = Counter()
    review1_findings_total = 0
    review1_note_samples = []

    implementation_runs_total = 0
    implementation_contract_requirements_total = 0
    implementation_requirements_done_total = 0
    implementation_self_reported_known_gaps = 0
    implementation_validation_commands_total = 0
    implementation_note_samples = []

    final_review_runs_total = 0
    final_release_decisions = Counter()
    final_total_findings = 0
    final_new_findings_missed_by_review1 = 0
    final_carried_findings_from_review1 = 0
    final_resolved_findings_from_review1 = 0
    final_blocking_findings = 0
    final_categories = Counter()
    final_implementer_mistakes_missed_by_review1 = Counter()
    final_note_samples = []

    closeout_runs_total = 0
    closeout_release_decisions = Counter()
    closeout_note_samples = []

    for run_dir in sorted(CANONICAL_RUNS.iterdir() if CANONICAL_RUNS.exists() else []):
        if not run_dir.is_dir():
            continue
        meta = load_json(run_dir / "meta.json")
        if not meta:
            continue

        runs_total += 1
        intent = meta.get("intent", "unknown")
        starter = meta.get("starter", "unknown")
        oracle_model = meta.get("oracle_model") or "unknown"
        sisyphus_model = meta.get("sisyphus_model") or "unknown"
        pair_key = f"{oracle_model}__{sisyphus_model}"

        by_intent[intent] += 1
        by_starter[starter] += 1
        oracle_models[oracle_model] += 1
        sisyphus_models[sisyphus_model] += 1
        model_pairs[pair_key] += 1
        completed_stages = canonical_stage_counts(run_dir / "stage-log.jsonl")
        stage_complete_counts.update(completed_stages)
        implementation_completed = completed_stages.get("implement-from-contract", 0) > 0
        review1_completed = completed_stages.get("review1-from-contract", 0) > 0
        oracle_final_completed = completed_stages.get("oracle-final-review", 0) > 0

        score = load_json(run_dir / "02-debate-score.json")
        if score:
            debate_runs_total += 1
            overall_verdict = score.get("overall_verdict", "unknown")
            debate_overall[overall_verdict] += 1
            debate_by_pair[pair_key][overall_verdict] += 1
            for issue in score.get("issues", []):
                debate_issue_count += 1
                verdict = issue.get("verdict", "unknown")
                status = issue.get("status", "unknown")
                debate_issue_verdicts[verdict] += 1
                debate_issue_statuses[status] += 1
                if issue.get("adopted_in_contract") is True:
                    debate_adopted_true += 1

        debate_meta = load_json(run_dir / "debate-meta.json")
        if debate_meta:
            debate_meta_runs_total += 1
            debate_meta_evaluators[debate_meta.get("meta_evaluator", "unknown")] += 1
            debate_meta_evaluator_models[debate_meta.get("meta_evaluator_model", "unknown")] += 1
            oracle_profile = debate_meta.get("oracle_profile", {})
            sisyphus_profile = debate_meta.get("sisyphus_profile", {})
            comparative = debate_meta.get("comparative", {})
            for dimension in PROFILE_DIMENSIONS:
                debate_meta_oracle_profiles[dimension][oracle_profile.get(dimension, "unknown")] += 1
                debate_meta_sisyphus_profiles[dimension][sisyphus_profile.get(dimension, "unknown")] += 1
            for dimension in COMPARATIVE_DIMENSIONS:
                debate_meta_comparative[dimension][comparative.get(dimension, "unknown")] += 1
            append_note_sample(
                debate_meta_note_samples,
                task_id=run_dir.name,
                stage="debate-meta",
                actor=debate_meta.get("meta_evaluator", "unknown"),
                model=debate_meta.get("meta_evaluator_model", "unknown"),
                notes=debate_meta.get("notes", ""),
            )

        shadow_report = load_json(run_dir / "oracle" / "shadow-implementation-report.json")
        if shadow_report:
            append_note_sample(
                implementation_note_samples,
                task_id=run_dir.name,
                stage="oracle-shadow-implement",
                actor="oracle",
                model=oracle_model,
                notes=shadow_report.get("model_notes", ""),
            )

        review1_summary = run_dir / "04-review1.md"
        implementation_report = load_json(run_dir / "sisyphus" / "implementation-report.json")
        if implementation_completed and implementation_report:
            implementation_runs_total += 1
            summary = implementation_report.get("summary", {})
            implementation_contract_requirements_total += int(summary.get("contract_requirements_total", 0))
            implementation_requirements_done_total += int(summary.get("implemented_requirements_count", 0))
            implementation_self_reported_known_gaps += int(summary.get("self_reported_known_gaps", 0))
            implementation_validation_commands_total += int(summary.get("validation_commands_run", 0))
            append_note_sample(
                implementation_note_samples,
                task_id=run_dir.name,
                stage="implement-from-contract",
                actor="sisyphus",
                model=sisyphus_model,
                notes=implementation_report.get("model_notes", ""),
            )

        final_fix_report = load_json(run_dir / "sisyphus" / "final-fix-report.json")
        if completed_stages.get("fix-from-final", 0) > 0 and final_fix_report:
            append_note_sample(
                implementation_note_samples,
                task_id=run_dir.name,
                stage="fix-from-final",
                actor="sisyphus",
                model=sisyphus_model,
                notes=final_fix_report.get("model_notes", ""),
            )

        if review1_completed and review1_summary.is_file():
            review1_runs_total += 1
            review_paths = {
                "code": run_dir / "review1" / "code-review.md",
                "security": run_dir / "review1" / "security-review.md",
                "architecture": run_dir / "review1" / "architecture-review.md",
            }
            for review_type, review_path in review_paths.items():
                text = read_text(review_path)
                for severity in SEVERITIES:
                    block = level_section_text(text, f"## {severity.capitalize()}")
                    findings = count_bullets(block)
                    review1_findings[review_type][severity] += findings
                    review1_total_findings[severity] += findings

            findings_json = load_json(run_dir / "review1" / "findings.json")
            if findings_json:
                summary = findings_json.get("summary", {})
                review1_findings_total += int(summary.get("total_findings", 0))
                by_part = summary.get("by_part", {})
                for review_type in REVIEW_TYPES:
                    review1_part_totals[review_type] += int(by_part.get(review_type, {}).get("total", 0))
                for category in FINDING_CATEGORIES:
                    review1_implementer_mistakes[category] += int(
                        summary.get("implementer_mistakes", {}).get(category, 0)
                    )
                append_note_sample(
                    review1_note_samples,
                    task_id=run_dir.name,
                    stage="review1-from-contract",
                    actor="sisyphus",
                    model=sisyphus_model,
                    notes=findings_json.get("model_notes", ""),
                )

        final_text = read_text(run_dir / "05-oracle-final.md")
        if oracle_final_completed and final_text:
            final_review_runs_total += 1
            final_release_decisions[extract_release_decision(final_text)] += 1
            final_report = load_json(run_dir / "oracle" / "final-report.json")
            if final_report:
                summary = final_report.get("summary", {})
                final_total_findings += int(summary.get("oracle_total_findings", 0))
                final_new_findings_missed_by_review1 += int(summary.get("oracle_new_findings_missed_by_review1", 0))
                final_carried_findings_from_review1 += int(summary.get("oracle_carried_findings_from_review1", 0))
                final_resolved_findings_from_review1 += int(summary.get("oracle_resolved_findings_from_review1", 0))
                final_blocking_findings += int(summary.get("blocking_findings", 0))
                for category in FINDING_CATEGORIES:
                    final_implementer_mistakes_missed_by_review1[category] += int(
                        summary.get("implementer_mistakes_missed_by_review1", {}).get(category, 0)
                    )
                for finding in final_report.get("findings", []):
                    final_categories[finding.get("category", "unknown")] += 1
                append_note_sample(
                    final_note_samples,
                    task_id=run_dir.name,
                    stage="oracle-final-review",
                    actor="oracle",
                    model=oracle_model,
                    notes=final_report.get("model_notes", ""),
                )

        closeout_report = load_json(run_dir / "oracle" / "closeout-report.json")
        if completed_stages.get("oracle-closeout", 0) > 0 and closeout_report:
            closeout_runs_total += 1
            closeout_release_decisions[closeout_report.get("decision", "unknown")] += 1
            append_note_sample(
                closeout_note_samples,
                task_id=run_dir.name,
                stage="oracle-closeout",
                actor="oracle",
                model=oracle_model,
                notes=closeout_report.get("model_notes", ""),
            )

    return {
        "runs_total": runs_total,
        "by_intent": dict(by_intent),
        "by_starter": dict(by_starter),
        "stage_complete_counts": dict(stage_complete_counts),
        "model_pairs": dict(model_pairs),
        "oracle_models": dict(oracle_models),
        "sisyphus_models": dict(sisyphus_models),
        "debate": {
            "runs_total": debate_runs_total,
            "issue_count": debate_issue_count,
            "overall_verdict_counts": dict(debate_overall),
            "issue_verdict_counts": dict(debate_issue_verdicts),
            "issue_status_counts": dict(debate_issue_statuses),
            "adopted_in_contract_true": debate_adopted_true,
            "by_model_pair_overall_verdicts": {pair: dict(counter) for pair, counter in debate_by_pair.items()},
        },
        "debate_meta": {
            "runs_total": debate_meta_runs_total,
            "meta_evaluators": dict(debate_meta_evaluators),
            "meta_evaluator_models": dict(debate_meta_evaluator_models),
            "oracle_profiles": {
                dimension: dict(counter)
                for dimension, counter in debate_meta_oracle_profiles.items()
            },
            "sisyphus_profiles": {
                dimension: dict(counter)
                for dimension, counter in debate_meta_sisyphus_profiles.items()
            },
            "comparative": {
                dimension: dict(counter)
                for dimension, counter in debate_meta_comparative.items()
            },
            "note_samples": debate_meta_note_samples[-5:],
        },
        "review1": {
            "runs_total": review1_runs_total,
            "findings_total": review1_findings_total,
            "findings_by_review_type": review1_findings,
            "findings_total_by_part": dict(review1_part_totals),
            "total_findings_by_severity": dict(review1_total_findings),
            "implementer_mistakes_by_category": dict(review1_implementer_mistakes),
            "note_samples": review1_note_samples[-5:],
        },
        "implementation": {
            "runs_total": implementation_runs_total,
            "contract_requirements_total": implementation_contract_requirements_total,
            "implemented_requirements_count": implementation_requirements_done_total,
            "self_reported_known_gaps": implementation_self_reported_known_gaps,
            "validation_commands_run": implementation_validation_commands_total,
            "note_samples": implementation_note_samples[-5:],
        },
        "oracle_final": {
            "runs_total": final_review_runs_total,
            "release_decision_counts": dict(final_release_decisions),
            "oracle_total_findings": final_total_findings,
            "oracle_new_findings_missed_by_review1": final_new_findings_missed_by_review1,
            "oracle_carried_findings_from_review1": final_carried_findings_from_review1,
            "oracle_resolved_findings_from_review1": final_resolved_findings_from_review1,
            "blocking_findings": final_blocking_findings,
            "findings_by_category": dict(final_categories),
            "implementer_mistakes_missed_by_review1": dict(final_implementer_mistakes_missed_by_review1),
            "note_samples": final_note_samples[-5:],
        },
        "oracle_closeout": {
            "runs_total": closeout_runs_total,
            "release_decision_counts": dict(closeout_release_decisions),
            "note_samples": closeout_note_samples[-5:],
        },
    }


def aggregate_legacy_runs() -> dict:
    runs_total = 0
    stage_presence = Counter()
    review1_runs_total = 0
    review1_observation_counts = Counter()
    final_runs_total = 0
    final_decision_counts = Counter()

    for run_dir in sorted(LEGACY_RUNS.iterdir() if LEGACY_RUNS.exists() else []):
        if not run_dir.is_dir():
            continue
        debate_path = run_dir / "01-debate.md"
        contract_path = run_dir / "02-contract.md"
        review1_path = run_dir / "03-review1.md"
        final_path = run_dir / "04-codex-final.md"

        if not any(path.is_file() for path in (debate_path, contract_path, review1_path, final_path)):
            continue

        runs_total += 1
        if debate_path.is_file():
            stage_presence["debate"] += 1
        if contract_path.is_file():
            stage_presence["contract"] += 1
        if review1_path.is_file():
            stage_presence["review1"] += 1
            review1_runs_total += 1
            review1_text = read_text(review1_path)
            review1_observation_counts["review_result_bullets"] += count_bullets(section_text(review1_text, "## 리뷰 결과"))
            review1_observation_counts["open_issue_bullets"] += count_bullets(section_text(review1_text, "## 열린 쟁점"))
            review1_observation_counts["remaining_risk_bullets"] += count_bullets(section_text(review1_text, "## 남은 리스크"))
        if final_path.is_file():
            stage_presence["oracle_final"] += 1
            final_runs_total += 1
            final_decision_counts[extract_release_decision(read_text(final_path))] += 1

    return {
        "runs_total": runs_total,
        "stage_presence_counts": dict(stage_presence),
        "review1": {
            "runs_total": review1_runs_total,
            "observation_counts": dict(review1_observation_counts),
        },
        "oracle_final": {
            "runs_total": final_runs_total,
            "release_decision_counts": dict(final_decision_counts),
        },
        "notes": [
            "legacy runs do not have canonical score/model/stage-log structure",
            "legacy debate quality and review severity are therefore treated as partial statistics only",
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Aggregate Sisyphus-Oracle protocol stats.")
    parser.add_argument("--output", type=Path, help="Optional path to write the aggregated JSON.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output.")
    args = parser.parse_args()

    report = {
        "schema_version": 3,
        "canonical_source": str(CANONICAL_RUNS),
        "legacy_source": str(LEGACY_RUNS),
        "canonical": aggregate_canonical_runs(),
        "legacy": aggregate_legacy_runs(),
        "guidance": {
            "debate_quality_source_of_truth": "canonical.02-debate-score.json",
            "debate_meta_source_of_truth": "canonical.debate-meta.json",
            "review_quality_source_of_truth": "canonical.review1/* and canonical.05-oracle-final.md",
            "implementation_note_source_of_truth": "canonical.*report.json model_notes",
            "legacy_scope": "flow stats and partial review/oracle signals only",
        },
    }

    output_text = json.dumps(report, ensure_ascii=False, indent=2 if args.pretty or args.output else None)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_text + ("\n" if not output_text.endswith("\n") else ""))
    print(output_text)


if __name__ == "__main__":
    main()
