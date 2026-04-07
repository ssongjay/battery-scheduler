#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
from typing import Dict


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = ROOT / ".protocol" / "stats" / "latest.json"
DEFAULT_OUTPUT = ROOT / ".protocol" / "stats" / "dashboard.html"

LABELS = {
    "codex": "Codex",
    "claude-code": "Claude Code",
    "discussion_only": "토론 전용",
    "implementation_bound": "구현 연계",
    "oracle": "오라클",
    "sisyphus": "시지푸스",
    "starter": "시작자",
    "balanced": "균형",
    "unresolved": "미해결",
    "oracle_dominant": "오라클 우세",
    "sisyphus_dominant": "시지푸스 우세",
    "converged": "수렴",
    "resolved": "해결됨",
    "debate-discuss": "토론 종료",
    "debate-build": "계약 준비 완료",
    "oracle-pre-impl-guardrails": "오라클 구현 가드레일 완료",
    "oracle-shadow-implement": "오라클 그림자 구현 완료",
    "implement-from-contract": "구현 완료",
    "review1-from-contract": "1차 리뷰 완료",
    "oracle-final-review": "오라클 최종 리뷰 완료",
    "fix-from-final": "최종 지적 반영 완료",
    "oracle-closeout": "오라클 종료 승인 완료",
    "debate-meta": "토론 메타",
    "high": "높음",
    "medium": "중간",
    "low": "낮음",
    "problem_framing": "문제 프레이밍",
    "bottleneck_identification": "병목 식별",
    "guardrail_design": "가드레일 설계",
    "convergence_driving": "수렴 주도",
    "abstraction_level": "추상화 수준",
    "risk_posture": "위험 성향",
    "evidence_orientation": "증거 지향성",
    "execution_bias": "실행 편향",
    "adaptability": "적응성",
    "critical": "치명",
    "approve": "승인",
    "hold": "보류",
    "reject": "반려",
}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def fmt_int(value: int) -> str:
    return f"{value:,}"


def translate(label: str) -> str:
    return LABELS.get(label, label)


def summary_item(title: str, value: str, note: str = "") -> str:
    note_html = f'<div class="summary-note">{html.escape(note)}</div>' if note else ""
    return f"""
    <div class="summary-item">
      <div class="summary-label">{html.escape(title)}</div>
      <div class="summary-value">{html.escape(value)}</div>
      {note_html}
    </div>
    """


def pct(value: int, total: int) -> str:
    if total <= 0:
        return "0%"
    return f"{(value / total) * 100:.1f}%"


def total_of(data: Dict[str, int]) -> int:
    return sum(data.values()) if data else 0


def bar_rows(data: Dict[str, int], total: int | None = None, empty_label: str = "데이터 없음") -> str:
    if not data:
        return f'<div class="empty">{html.escape(empty_label)}</div>'
    if total is None:
        total = max(data.values()) if data else 0
    total = max(total, 1)
    base = max(total_of(data), 1)
    if base <= 3:
        items = []
        for label, value in sorted(data.items(), key=lambda item: (-item[1], item[0])):
            items.append(
                f"""
                <div class="compact-item">
                  <span class="compact-label">{html.escape(translate(str(label)))}</span>
                  <span class="compact-value">{fmt_int(value)}</span>
                </div>
                """
            )
        return f'<div class="compact-list">{"".join(items)}</div>'
    rows = []
    for label, value in sorted(data.items(), key=lambda item: (-item[1], item[0])):
        width = (value / total) * 100
        suffix = "" if base <= 5 else f' <span class="muted">({pct(value, base)})</span>'
        rows.append(
            f"""
            <div class="bar-row">
              <div class="bar-meta">
                <span class="bar-label">{html.escape(translate(str(label)))}</span>
                <span class="bar-value">{fmt_int(value)}{suffix}</span>
              </div>
              <div class="bar-track"><div class="bar-fill" style="width:{width:.2f}%"></div></div>
            </div>
            """
        )
    return "\n".join(rows)


def key_value_rows(data: Dict[str, int | str], empty_label: str = "데이터 없음") -> str:
    if not data:
        return f'<div class="empty">{html.escape(empty_label)}</div>'
    rows = []
    for key, value in data.items():
        rows.append(
            f"""
            <div class="kv-row">
              <span class="kv-key">{html.escape(translate(str(key)))}</span>
              <span class="kv-value">{html.escape(str(value))}</span>
            </div>
            """
        )
    return "\n".join(rows)


def dominant_label(data: Dict[str, int]) -> str:
    if not data:
        return "데이터 없음"
    label, value = sorted(data.items(), key=lambda item: (-item[1], item[0]))[0]
    if total_of(data) <= 1:
        return translate(str(label))
    return f"{translate(str(label))} ({fmt_int(value)})"


def dominant_model_pair_label(model_pairs: Dict[str, int]) -> str:
    if not model_pairs:
        return "데이터 없음"
    pair, count = sorted(model_pairs.items(), key=lambda item: (-item[1], item[0]))[0]
    oracle_model, sisyphus_model = pair.split("__", 1) if "__" in pair else (pair, "")
    label = f"{translate(oracle_model)} / {translate(sisyphus_model)}".strip(" /")
    if total_of(model_pairs) <= 1:
        return label
    return f"{label} ({fmt_int(count)})"


def profile_rows(profile: Dict[str, Dict[str, int]], empty_label: str) -> str:
    if not profile:
        return f'<div class="empty">{html.escape(empty_label)}</div>'
    order = [
        "abstraction_level",
        "risk_posture",
        "evidence_orientation",
        "execution_bias",
        "adaptability",
    ]
    rows = ['<div class="metric-grid">']
    for dimension in order:
        rows.append(
            f"""
            <div class="metric-card">
              <div class="metric-label">{html.escape(translate(dimension))}</div>
              <div class="metric-value">{html.escape(dominant_label(profile.get(dimension, {})))}</div>
            </div>
            """
        )
    rows.append("</div>")
    return "\n".join(rows)


def comparative_rows(comp: Dict[str, Dict[str, int]], empty_label: str) -> str:
    if not comp:
        return f'<div class="empty">{html.escape(empty_label)}</div>'
    order = [
        "problem_framing",
        "bottleneck_identification",
        "guardrail_design",
        "convergence_driving",
    ]
    rows = ['<div class="metric-grid">']
    for dimension in order:
        rows.append(
            f"""
            <div class="metric-card">
              <div class="metric-label">{html.escape(translate(dimension))}</div>
              <div class="metric-value">{html.escape(dominant_label(comp.get(dimension, {})))}</div>
            </div>
            """
        )
    rows.append("</div>")
    return "\n".join(rows)


def pair_cards(model_pairs: Dict[str, int]) -> str:
    if not model_pairs:
        return '<div class="empty">모델 조합 데이터 없음</div>'
    cards = []
    for pair, count in sorted(model_pairs.items(), key=lambda item: (-item[1], item[0])):
        oracle_model, sisyphus_model = pair.split("__", 1) if "__" in pair else (pair, "")
        cards.append(
            f"""
            <div class="pair-card">
              <div class="pair-eyebrow">오라클 / 시지푸스</div>
              <div class="pair-title">{html.escape(translate(oracle_model))} / {html.escape(translate(sisyphus_model))}</div>
              <div class="pair-count">{fmt_int(count)}건</div>
            </div>
            """
        )
    return "\n".join(cards)


def note_cards(samples: list[dict], empty_label: str = "성향 해석 메모 없음") -> str:
    if not samples:
        return f'<div class="empty">{html.escape(empty_label)}</div>'
    cards = []
    for sample in samples:
        task_id = sample.get("task_id", "")
        stage = translate(str(sample.get("stage", "")))
        actor = translate(str(sample.get("actor", "")))
        model = translate(str(sample.get("model", "")))
        notes = html.escape(sample.get("notes", ""))
        cards.append(
            f"""
            <div class="note-card">
              <div class="note-meta">{html.escape(task_id)} · {html.escape(stage)} · {html.escape(actor)} / {html.escape(model)}</div>
              <div class="note-body">{notes}</div>
            </div>
            """
        )
    return "\n".join(cards)


def bullet_list(items: list[str], empty_label: str = "데이터 없음") -> str:
    if not items:
        return f'<div class="empty">{html.escape(empty_label)}</div>'
    rows = []
    for item in items:
        rows.append(f'<li>{html.escape(item)}</li>')
    return f'<ul class="signal-list">{"".join(rows)}</ul>'


def insight_lines(canonical: dict, debate: dict, debate_meta: dict, implementation: dict, review1: dict, oracle_final: dict, closeout: dict) -> list[str]:
    lines = [f"기준 run은 {fmt_int(canonical.get('runs_total', 0))}건이며, 이 페이지는 canonical 기록을 우선 진실로 본다."]
    if debate.get("overall_verdict_counts"):
        lines.append(f"토론의 대표 판정은 {dominant_label(debate['overall_verdict_counts'])}이다.")
    if debate.get("issue_status_counts"):
        lines.append(f"논점 상태는 {dominant_label(debate['issue_status_counts'])} 쪽으로 기울어 있다.")
    if debate_meta.get("comparative", {}).get("bottleneck_identification"):
        lines.append(f"병목 식별 우세 축은 {dominant_label(debate_meta['comparative']['bottleneck_identification'])}이다.")
    if closeout.get("release_decision_counts"):
        lines.append(f"fix 이후 종료 판정은 {dominant_label(closeout['release_decision_counts'])}이다.")
    if implementation.get("runs_total", 0) == 0 and review1.get("runs_total", 0) == 0 and oracle_final.get("runs_total", 0) == 0:
        lines.append("구현·리뷰 파이프라인은 아직 비어 있어, 다음 의미 있는 데이터는 첫 implementation_bound run에서 생긴다.")
    return lines[:4]


def section_heading(label: str, title: str, copy: str) -> str:
    return f"""
    <div class="section-heading">
      <div class="section-label">{html.escape(label)}</div>
      <h2>{html.escape(title)}</h2>
      <p>{html.escape(copy)}</p>
    </div>
    """


def humanize_legacy_note(note: str) -> str:
    mapping = {
        "legacy runs do not have canonical score/model/stage-log structure": "legacy run에는 canonical score/model/stage-log 구조가 없다.",
        "legacy debate quality and review severity are therefore treated as partial statistics only": "따라서 legacy의 토론 품질과 리뷰 심각도는 부분 통계로만 해석해야 한다.",
    }
    return mapping.get(note, note)


def render_dashboard(report: dict) -> str:
    canonical = report["canonical"]
    legacy = report["legacy"]
    debate = canonical["debate"]
    debate_meta = canonical.get("debate_meta", {})
    review1 = canonical["review1"]
    implementation = canonical["implementation"]
    oracle_final = canonical["oracle_final"]
    closeout = canonical.get("oracle_closeout", {})

    summary_html = "".join(
        [
            summary_item("기준 실행", f"{fmt_int(canonical['runs_total'])}건", "정본 기록"),
            summary_item("레거시 실행", f"{fmt_int(legacy['runs_total'])}건", "비교용 이력"),
            summary_item("누적 논점", f"{fmt_int(debate['issue_count'])}건", "토론 score 기준"),
            summary_item("구현 run", f"{fmt_int(implementation['runs_total'])}건", "구현 연계"),
            summary_item("Review1", f"{fmt_int(review1['runs_total'])}건", "정식 리뷰 번들"),
            summary_item("Oracle Final", f"{fmt_int(oracle_final['runs_total'])}건", "최종 리뷰"),
            summary_item("Closeout", f"{fmt_int(closeout.get('runs_total', 0))}건", "fix 이후 종료"),
        ]
    )

    legacy_notes = "".join(f"<li>{html.escape(humanize_legacy_note(note))}</li>" for note in legacy.get("notes", []))
    debate_meta_notes_html = note_cards(debate_meta.get("note_samples", []))
    implementation_notes_html = note_cards(implementation.get("note_samples", []), empty_label="구현 메모 없음")
    review1_notes_html = note_cards(review1.get("note_samples", []), empty_label="Review1 메모 없음")
    final_notes_html = note_cards(
        oracle_final.get("note_samples", []) + closeout.get("note_samples", []),
        empty_label="Final / Closeout 메모 없음",
    )
    insights_html = bullet_list(
        insight_lines(canonical, debate, debate_meta, implementation, review1, oracle_final, closeout),
        empty_label="핵심 해석 없음",
    )
    operational_kv = key_value_rows(
        {
            "주 판독 기준": "canonical .protocol",
            "대표 판정": dominant_label(debate.get("overall_verdict_counts", {})),
            "메타 평가자": dominant_label(debate_meta.get("meta_evaluators", {})),
            "모델 조합": dominant_model_pair_label(canonical.get("model_pairs", {})),
            "종료 판정": dominant_label(closeout.get("release_decision_counts", {})),
        },
        empty_label="운영 요약 데이터 없음",
    )

    return f"""<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>시지푸스-오라클 통계 대시보드</title>
  <style>
    :root {{
      --paper: #f6f0e6;
      --panel: rgba(255, 252, 247, 0.84);
      --panel-strong: #fffaf2;
      --ink: #181512;
      --muted: #655c53;
      --line: rgba(95, 78, 60, 0.18);
      --line-strong: rgba(95, 78, 60, 0.32);
      --accent: #1f5c52;
      --accent-soft: rgba(31, 92, 82, 0.1);
      --warning: #8c5a2b;
      --shadow: 0 18px 50px rgba(39, 29, 19, 0.06);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      color: var(--ink);
      background:
        linear-gradient(180deg, rgba(255,255,255,0.35), rgba(255,255,255,0)) 0 0 / 100% 220px no-repeat,
        repeating-linear-gradient(180deg, rgba(0,0,0,0.016) 0, rgba(0,0,0,0.016) 1px, transparent 1px, transparent 36px),
        var(--paper);
      font-family: "SUIT Variable", "Pretendard", "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
    }}
    .page {{
      max-width: 1320px;
      margin: 0 auto;
      padding: 24px 18px 48px;
    }}
    .masthead {{
      display: grid;
      grid-template-columns: minmax(0, 1.45fr) minmax(280px, 0.9fr);
      gap: 22px;
      padding: 24px 0 22px;
      border-bottom: 1px solid var(--line-strong);
      margin-bottom: 18px;
    }}
    .masthead-eyebrow {{
      color: var(--muted);
      font-size: 12px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      font-weight: 700;
      margin-bottom: 16px;
    }}
    .masthead h1 {{
      margin: 0 0 14px;
      font-family: "Iowan Old Style", "Palatino Linotype", "Noto Serif KR", serif;
      font-size: clamp(2.2rem, 5vw, 4.2rem);
      line-height: 0.98;
      letter-spacing: -0.04em;
      font-weight: 700;
      max-width: 11ch;
    }}
    .masthead p {{
      margin: 0;
      max-width: 60ch;
      color: var(--muted);
      font-size: 15px;
      line-height: 1.7;
    }}
    .masthead-note {{
      background: var(--panel);
      border: 1px solid var(--line);
      box-shadow: var(--shadow);
      border-radius: 22px;
      padding: 18px 18px 16px;
    }}
    .masthead-note-title {{
      color: var(--muted);
      font-size: 12px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      font-weight: 700;
      margin-bottom: 10px;
    }}
    .summary-strip {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 12px;
      margin-bottom: 18px;
    }}
    .summary-item {{
      min-height: 102px;
      padding: 14px 14px 12px;
      border-radius: 18px;
      border: 1px solid var(--line);
      background: linear-gradient(180deg, rgba(255,255,255,0.72), rgba(255,250,243,0.9));
      box-shadow: var(--shadow);
    }}
    .summary-label {{
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.05em;
      margin-bottom: 12px;
    }}
    .summary-value {{
      font-size: 28px;
      line-height: 1.05;
      letter-spacing: -0.04em;
      font-weight: 800;
    }}
    .summary-note {{
      margin-top: 10px;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.45;
    }}
    .main-grid {{
      display: grid;
      grid-template-columns: repeat(12, minmax(0, 1fr));
      gap: 16px;
    }}
    .section {{
      grid-column: span 12;
      background: var(--panel);
      border: 1px solid var(--line);
      box-shadow: var(--shadow);
      border-radius: 24px;
      padding: 20px 20px 18px;
    }}
    .span-7 {{ grid-column: span 7; }}
    .span-5 {{ grid-column: span 5; }}
    .span-12 {{ grid-column: span 12; }}
    .section-heading {{
      margin-bottom: 16px;
    }}
    .section-label {{
      color: var(--muted);
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      margin-bottom: 10px;
    }}
    .section h2 {{
      margin: 0 0 8px;
      font-size: 26px;
      line-height: 1.1;
      letter-spacing: -0.03em;
      font-weight: 800;
    }}
    .section-heading p {{
      margin: 0;
      color: var(--muted);
      font-size: 14px;
      line-height: 1.6;
    }}
    .dual {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 14px;
    }}
    .tri {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px;
    }}
    .detail-card {{
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 15px 15px 14px;
      background: linear-gradient(180deg, rgba(255,255,255,0.78), rgba(255,249,241,0.92));
    }}
    .detail-title {{
      color: var(--muted);
      font-size: 12px;
      margin-bottom: 12px;
      letter-spacing: 0.05em;
      font-weight: 700;
    }}
    .bar-row {{
      margin-bottom: 14px;
    }}
    .bar-meta {{
      display: flex;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 7px;
      font-size: 14px;
      line-height: 1.4;
    }}
    .bar-label {{
      font-weight: 700;
    }}
    .bar-track {{
      width: 100%;
      height: 8px;
      background: rgba(116, 96, 73, 0.1);
      border-radius: 999px;
      overflow: hidden;
    }}
    .bar-fill {{
      height: 100%;
      background: linear-gradient(90deg, var(--accent), #3d8679);
      border-radius: 999px;
    }}
    .muted {{ color: var(--muted); }}
    .kv-row {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 14px;
      padding: 12px 0;
      border-top: 1px dashed var(--line);
    }}
    .kv-row:first-child {{
      border-top: 0;
      padding-top: 0;
    }}
    .kv-key {{
      color: var(--muted);
      font-size: 14px;
    }}
    .kv-value {{
      font-weight: 700;
      font-size: 15px;
      text-align: right;
    }}
    .pair-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 12px;
    }}
    .pair-card {{
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 14px 14px 16px;
      background: linear-gradient(180deg, rgba(255,255,255,0.8), rgba(255,248,238,0.94));
    }}
    .pair-eyebrow {{
      color: var(--muted);
      font-size: 12px;
      letter-spacing: 0.05em;
      margin-bottom: 6px;
      font-weight: 700;
    }}
    .pair-title {{
      font-weight: 800;
      font-size: 18px;
      line-height: 1.25;
      margin-bottom: 8px;
    }}
    .pair-count {{
      color: var(--muted);
      font-size: 14px;
    }}
    .compact-list {{
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
    }}
    .compact-item {{
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 9px 13px;
      border-radius: 14px;
      border: 1px solid var(--line);
      background: rgba(255, 252, 247, 0.88);
    }}
    .compact-label {{
      color: var(--ink);
      font-size: 14px;
      font-weight: 700;
    }}
    .compact-value {{
      color: var(--muted);
      font-size: 14px;
      font-weight: 700;
    }}
    .metric-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }}
    .metric-card {{
      border: 1px solid var(--line);
      border-radius: 16px;
      padding: 14px;
      background: rgba(255, 252, 247, 0.88);
    }}
    .metric-label {{
      color: var(--muted);
      font-size: 13px;
      margin-bottom: 8px;
      line-height: 1.35;
    }}
    .metric-value {{
      font-size: 18px;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: -0.02em;
    }}
    .note-stack {{
      display: grid;
      gap: 12px;
    }}
    .note-card {{
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 16px;
      background: rgba(255, 252, 247, 0.9);
    }}
    .note-meta {{
      color: var(--muted);
      font-size: 12px;
      margin-bottom: 8px;
      font-weight: 700;
      letter-spacing: 0.02em;
    }}
    .note-body {{
      font-size: 15px;
      line-height: 1.6;
      color: var(--ink);
    }}
    .empty {{
      color: var(--muted);
      font-style: italic;
    }}
    .signal-list,
    .note-list {{
      margin: 0;
      padding-left: 18px;
      line-height: 1.7;
    }}
    .signal-list {{
      color: var(--ink);
      font-size: 14px;
    }}
    .note-list {{
      color: var(--muted);
      font-size: 14px;
    }}
    .subhead {{
      margin-top: 16px;
      margin-bottom: 10px;
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.05em;
    }}
    .pipeline-grid {{
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 14px;
    }}
    .footer {{
      margin-top: 18px;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.5;
    }}
    .source {{
      margin-top: 18px;
      color: var(--muted);
      font-size: 13px;
      text-align: left;
    }}
    @media (max-width: 1100px) {{
      .tri,
      .pipeline-grid {{
        grid-template-columns: 1fr;
      }}
    }}
    @media (max-width: 980px) {{
      .masthead,
      .dual,
      .metric-grid {{
        grid-template-columns: 1fr;
      }}
      .span-7, .span-5 {{
        grid-column: span 12;
      }}
    }}
    @media (max-width: 720px) {{
      .page {{
        padding: 16px 12px 34px;
      }}
      .summary-strip {{
        grid-template-columns: 1fr;
      }}
      .section {{
        padding: 18px 16px 16px;
      }}
    }}
  </style>
</head>
<body>
  <div class="page">
    <header class="masthead">
      <div>
        <div class="masthead-eyebrow">Buy Good Things / Protocol Ledger</div>
        <h1>시지푸스-오라클 실행 통계</h1>
        <p>canonical run을 기준으로 토론, 구현, 리뷰 게이트가 실제로 얼마나 닫혔는지 읽는 내부용 페이지입니다. 화려한 KPI 대시보드보다, 지금 무엇이 채워졌고 무엇이 아직 비었는지를 차분하게 파악하는 데 초점을 둡니다.</p>
      </div>
      <aside class="masthead-note">
        <div class="masthead-note-title">현재 판독</div>
        {insights_html}
      </aside>
    </header>

    <section class="summary-strip">
      {summary_html}
    </section>

    <div class="main-grid">
      <section class="section span-7">
        {section_heading("실행 구조", "실행 구조", "어떤 intent와 starter 조합으로 run이 열렸고, 어느 stage까지 실제 완료 이벤트가 남았는지 본다.")}
        <div class="dual">
          <div class="detail-card">
            <div class="detail-title">Intent / Starter</div>
            {bar_rows(canonical.get("by_intent", {}), empty_label="intent 데이터 없음")}
            <div class="subhead">Starter</div>
            {bar_rows(canonical.get("by_starter", {}), empty_label="starter 데이터 없음")}
          </div>
          <div class="detail-card">
            <div class="detail-title">단계 완료</div>
            {bar_rows(canonical.get("stage_complete_counts", {}), empty_label="완료된 단계 없음")}
          </div>
        </div>
      </section>

      <section class="section span-5">
        {section_heading("운영 판독", "현재 읽어야 할 포인트", "지금 이 데이터셋을 어떤 전제로 읽어야 하는지 한쪽에 모아 둔다.")}
        <div class="detail-card">
          <div class="detail-title">운영 요약</div>
          {operational_kv}
        </div>
        <div class="footer">모델 조합, 대표 판정, 메타 평가자는 모두 현재 누적 데이터의 최빈값 기준이다.</div>
      </section>

      <section class="section span-7">
        {section_heading("토론 품질", "토론 판단과 논점 상태", "overall verdict, issue verdict, issue status를 나눠서 본다. 논점이 정말 닫혔는지와 contract로 얼마나 이어졌는지가 핵심이다.")}
        <div class="dual">
          <div class="detail-card">
            <div class="detail-title">판정</div>
            {bar_rows(debate.get("overall_verdict_counts", {}), empty_label="토론 결과 없음")}
            <div class="subhead">논점별 판정</div>
            {bar_rows(debate.get("issue_verdict_counts", {}), empty_label="논점별 판정 없음")}
          </div>
          <div class="detail-card">
            <div class="detail-title">논점 상태</div>
            {bar_rows(debate.get("issue_status_counts", {}), empty_label="논점 상태 데이터 없음")}
            <div class="footer">계약 반영 수: {fmt_int(debate.get("adopted_in_contract_true", 0))}</div>
          </div>
        </div>
      </section>

      <section class="section span-5">
        {section_heading("모델 조합", "실행 조합", "오라클과 시지푸스가 어떤 모델 조합으로 돌아갔는지와 메타 평가 체계를 함께 본다.")}
        <div class="pair-grid">{pair_cards(canonical.get("model_pairs", {}))}</div>
        <div class="subhead">메타 평가자</div>
        {bar_rows(debate_meta.get("meta_evaluators", {}), empty_label="평가자 데이터 없음")}
      </section>

      <section class="section span-12">
        {section_heading("메타 판독", "모델 성향과 비교 우세 축", "토론 스타일을 숫자만으로 끝내지 않고, 프로파일 축과 메타 해석 메모까지 같이 읽는다.")}
        <div class="tri">
          <div class="detail-card">
            <div class="detail-title">오라클 성향</div>
            {profile_rows(debate_meta.get("oracle_profiles", {}), empty_label="오라클 성향 데이터 없음")}
          </div>
          <div class="detail-card">
            <div class="detail-title">시지푸스 성향</div>
            {profile_rows(debate_meta.get("sisyphus_profiles", {}), empty_label="시지푸스 성향 데이터 없음")}
          </div>
          <div class="detail-card">
            <div class="detail-title">비교 우세 축</div>
            {comparative_rows(debate_meta.get("comparative", {}), empty_label="비교 데이터 없음")}
          </div>
        </div>
        <div class="subhead">해석 메모</div>
        <div class="note-stack">{debate_meta_notes_html}</div>
      </section>

      <section class="section span-12">
        {section_heading("구현 파이프라인", "구현·리뷰 단계", "implementation_bound run이 쌓이기 시작하면 여기서 구현 누락, Review1 포착력, Oracle final 추가 포착력을 읽게 된다.")}
        <div class="pipeline-grid">
          <div class="detail-card">
            <div class="detail-title">구현</div>
            {key_value_rows({
              "run 수": implementation.get("runs_total", 0),
              "계약 요구사항 수": implementation.get("contract_requirements_total", 0),
              "구현된 요구사항 수": implementation.get("implemented_requirements_count", 0),
              "자기 보고 gap": implementation.get("self_reported_known_gaps", 0),
              "검증 명령 실행 수": implementation.get("validation_commands_run", 0)
            }, empty_label="구현 데이터 없음")}
          </div>
          <div class="detail-card">
            <div class="detail-title">1차 리뷰</div>
            {key_value_rows({
              "run 수": review1.get("runs_total", 0),
              "총 findings": review1.get("findings_total", 0)
            }, empty_label="1차 리뷰 데이터 없음")}
            <div class="subhead">파트별 findings</div>
            {bar_rows(review1.get("findings_total_by_part", {}), empty_label="파트별 데이터 없음")}
          </div>
          <div class="detail-card">
            <div class="detail-title">오라클 최종 리뷰</div>
            {bar_rows(oracle_final.get("release_decision_counts", {}), empty_label="오라클 최종 리뷰 데이터 없음")}
            <div class="footer">차단 이슈 수: {fmt_int(oracle_final.get("blocking_findings", 0))}</div>
          </div>
          <div class="detail-card">
            <div class="detail-title">오라클 종료 승인</div>
            {bar_rows(closeout.get("release_decision_counts", {}), empty_label="오라클 종료 승인 데이터 없음")}
            <div class="footer">closeout run 수: {fmt_int(closeout.get("runs_total", 0))}</div>
          </div>
        </div>
      </section>

      <section class="section span-12">
        {section_heading("구현 메모", "구현 단계 관찰 메모", "구현은 토론처럼 고정 축 점수보다, 이번 run에서 실제로 드러난 모델 특성을 텍스트로 남기는 편이 낫다.")}
        <div class="tri">
          <div class="detail-card">
            <div class="detail-title">구현 / Shadow / Fix</div>
            <div class="note-stack">{implementation_notes_html}</div>
          </div>
          <div class="detail-card">
            <div class="detail-title">Review1</div>
            <div class="note-stack">{review1_notes_html}</div>
          </div>
          <div class="detail-card">
            <div class="detail-title">Final / Closeout</div>
            <div class="note-stack">{final_notes_html}</div>
          </div>
        </div>
      </section>

      <section class="section span-12">
        {section_heading("legacy 경계", "legacy 데이터 해석 범위", "legacy run은 정식 canonical score/model/stage-log 구조가 없으므로, 흐름 확인과 부분 신호 정도로만 읽는다.")}
        <div class="dual">
          <div class="detail-card">
            <div class="detail-title">legacy 단계 존재</div>
            {bar_rows(legacy.get("stage_presence_counts", {}), empty_label="legacy 단계 데이터 없음")}
          </div>
          <div class="detail-card">
            <div class="detail-title">해석 메모</div>
            <ul class="note-list">{legacy_notes}</ul>
          </div>
        </div>
      </section>
    </div>

    <div class="source">
      Source JSON: {html.escape(str(DEFAULT_INPUT))}
    </div>
  </div>
</body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Render HTML dashboard from aggregated protocol stats.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Input aggregated JSON path.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Output HTML path.")
    args = parser.parse_args()

    report = load_json(args.input)
    html_text = render_dashboard(report)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(html_text, encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
