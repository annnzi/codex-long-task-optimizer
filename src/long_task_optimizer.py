"""CLI tool for turning long tasks into executable checkpoints."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path


DEFAULT_SAMPLE_PATH = Path(__file__).resolve().parents[1] / "examples" / "sample-task.txt"
APP_NAME = "codex-long-task-optimizer"
VERSION = "0.1.1"

DEFAULT_SAMPLE_PATH = Path(__file__).resolve().parents[1] / "examples" / "sample-task.txt"
CHECKPOINT_LABELS = ["澄清边界", "最小可交付", "核心实现", "验证收尾"]
SECTION_PATTERNS = {
    "目标": ("目标", "goal"),
    "范围": ("范围", "scope"),
    "交付": ("交付", "deliverable", "输出", "output"),
    "约束": ("约束", "constraints"),
    "验收": ("验收", "acceptance"),
}


@dataclass
class Checkpoint:
    title: str
    work: list[str]
    acceptance: list[str]
    rollback: str
    risks: list[str]
    est_tokens: int


def _read_text(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"文件不存在: {path}")
    return path.read_text(encoding="utf-8")


def _split_text(text: str, max_tokens: int) -> list[str]:
    if max_tokens <= 0:
        raise ValueError("max_tokens 必须大于 0")

    raw_chunks = [c.strip() for c in re.split(r"[。？！；;!\n\r]", text) if c.strip()]
    chunks = []
    current = []
    cur_tokens = 0
    for seg in raw_chunks:
        words = len(seg.split())
        if cur_tokens + words > max_tokens and current:
            chunks.append("；".join(current))
            current = [seg]
            cur_tokens = words
        else:
            current.append(seg)
            cur_tokens += words
    if current:
        chunks.append("；".join(current))
    return chunks


def _extract_sections(text: str) -> dict[str, str]:
    headers = {k: "" for k in SECTION_PATTERNS}
    lines = text.splitlines()
    current = "目标"
    key_map = {}
    for section, aliases in SECTION_PATTERNS.items():
        for alias in aliases:
            key_map[alias] = section
    for line in lines:
        line_stripped = line.strip()
        matched = None
        normalized = re.split(r"[:：]", line_stripped, maxsplit=1)[0].strip()
        for alias, section in key_map.items():
            if normalized.startswith(alias):
                matched = section
                break
        if matched:
            current = matched
            suffix = line_stripped[len(normalized):].lstrip(":：").strip()
            if suffix:
                headers[current] += (suffix + " ")
        else:
            headers[current] += (line_stripped + " ")
    return {k: v.strip() for k, v in headers.items()}


def _score_complexity(sections: dict[str, str]) -> int:
    base = len(sections["目标"]) + len(sections["交付"]) + len(sections["验收"])
    risk_terms = ["性能", "并发", "兼容", "回滚", "生产", "迁移", "重构", "兼容性"]
    penalty = sum(base.count(t) for t in risk_terms)
    return min(100, max(20, base // 6 + penalty))


def _build_checkpoints(chunks: list[str], no_risk: bool = False) -> list[Checkpoint]:
    checkpoints = []
    for idx, chunk in enumerate(chunks):
        title = f"阶段 {idx + 1}：{CHECKPOINT_LABELS[min(idx, len(CHECKPOINT_LABELS)-1)]}"
        work = [
            f"完成：{chunk}",
            "产出：阶段性结果文件或验证截图",
            "检查：确认前置条件与依赖可满足",
        ]
        acceptance = [
            "本阶段输出可独立验证",
            "无阻塞性高风险变更（如可回避则延后）",
        ]
        rollback = "将本阶段变更回退到上一次可验证提交"
        risks = [] if no_risk else [
            "需求边界不完整导致返工",
            "外部依赖文档不足导致时间偏差",
        ]
        est_tokens = len(chunk.split())
        checkpoints.append(Checkpoint(title, work, acceptance, rollback, risks, est_tokens))
    return checkpoints


def build_report(text: str, max_tokens: int = 120, no_risk: bool = False) -> dict:
    sections = _extract_sections(text)
    chunks = _split_text(text, max_tokens=max_tokens)
    checkpoints = _build_checkpoints(chunks, no_risk=no_risk)
    return {
        "generated_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "complexity": _score_complexity(sections),
        "summary": sections["目标"][:120] or "未识别到明确目标",
        "constraints": [x for x in [sections["约束"]] if x],
        "acceptance_targets": [x for x in [sections["验收"]] if x],
        "checkpoints": [asdict(c) for c in checkpoints],
    }


def _to_markdown(data: dict) -> str:
    lines = [
        "# 长任务优化结果",
        f"- 生成时间：{data['generated_at']}",
        f"- 复杂度：{data['complexity']}/100",
        f"- 目标摘要：{data['summary']}",
        f"- 估算风险项：{len(data['checkpoints'])} 阶段",
        "",
        "## 风险点与建议",
        "- 先写清边界，尽量只改一件事",
        "- 每个阶段保留可回退点",
        "- 关键结果先做验收，再推进下一阶段",
        "",
        "## 分解计划",
    ]
    for idx, c in enumerate(data["checkpoints"], start=1):
        lines.append(f"### {idx}. {c['title']}")
        lines.append(f"- 预估 token：{c['est_tokens']}")
        lines.append("- 待办：")
        lines.extend([f"  - {w}" for w in c["work"]])
        lines.append("- 验收：")
        lines.extend([f"  - {a}" for a in c["acceptance"]])
        lines.append(f"- 回退点：{c['rollback']}")
        if c["risks"]:
            lines.append("- 风险：")
            lines.extend([f"  - {r}" for r in c["risks"]])
        lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="将长任务按阶段拆解")
    parser.add_argument("--input", default=str(DEFAULT_SAMPLE_PATH), help="任务输入文件路径")
    parser.add_argument("--max-tokens", type=int, default=120, help="每个阶段最大 token 估算")
    parser.add_argument("--format", choices=["md", "json"], default="md", help="输出格式")
    parser.add_argument("--no-risk", action="store_true", help="不输出风险章节")
    parser.add_argument("--out", help="将结果写入到指定文件")
    parser.add_argument("--version", action="store_true", help="输出版本并退出")
    args = parser.parse_args()

    if args.version:
        print(f"{APP_NAME} {VERSION}")
        return

    text = _read_text(Path(args.input))
    report = build_report(text, max_tokens=args.max_tokens, no_risk=args.no_risk)

    if args.format == "json":
        output = json.dumps(report, ensure_ascii=False, indent=2)
    else:
        output = _to_markdown(report)

    if args.out:
        Path(args.out).write_text(output, encoding="utf-8")
    else:
        print(output)


if __name__ == "__main__":
    main()
