"""CLI tool for turning long tasks into executable checkpoints."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path

from src import __version__

DEFAULT_SAMPLE_PATH = Path(__file__).resolve().parents[1] / "examples" / "sample-task.txt"
APP_NAME = "codex-long-task-optimizer"
VERSION = __version__
CHECKPOINT_LABELS = ["澄清边界", "最小可交付", "核心实现", "验证收尾"]
DEFAULT_SAMPLE_TEXT = "目标：把长任务转成可执行阶段\n范围：演示默认输入可直接运行\n交付：输出含验收与回退的 Markdown / JSON 计划\n约束：单次运行不依赖外部服务\n验收：阶段结果可直接用于 Issue 或 PR 说明"
SECTION_PATTERNS = {
    "目标": ("目标", "goal", "goals"),
    "范围": ("范围", "scope", "scopes"),
    "交付": ("交付", "deliverable", "deliverables", "输出", "output", "outputs"),
    "约束": ("约束", "constraints", "constraint"),
    "验收": ("验收", "acceptance", "acceptances"),
}
SECTION_KEY_MAP = {
    alias.lower(): section
    for section, aliases in SECTION_PATTERNS.items()
    for alias in aliases
}
SECTION_LINE_PREFIX_PATTERNS = (
    r"^\s*#{1,6}\s+",
    r"^\s*[-*+]\s+",
    r"^\s*•\s+",
    r"^\s*\[[ xX]?\]\s+",
    r"^\s*\d+[.)]\s+",
    r"^\s*[（(]\d+[）)]\s+",
)


def _utc_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


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
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError(f"输入文件编码错误（需 UTF-8）：{path}") from exc


def _expand_path(value: str) -> Path:
    return Path(value).expanduser()


def _load_input_text(raw_input: str, raw_text: str | None) -> str:
    if raw_text is not None:
        text = raw_text.strip()
        if not text:
            raise ValueError("输入内容不能为空")
        return text

    if raw_input == "-":
        stdin_text = sys.stdin.read().strip()
        if not stdin_text:
            raise ValueError("从标准输入未读取到可解析任务内容（未检测到文本）")
        return stdin_text

    input_path = _expand_path(raw_input)
    try:
        return _read_text(input_path)
    except FileNotFoundError as exc:
        if input_path == DEFAULT_SAMPLE_PATH:
            print(f"默认示例不存在：{input_path}，已使用内置示例。", file=sys.stderr)
            return DEFAULT_SAMPLE_TEXT
        raise


def _segment_tokens(segment: str) -> tuple[list[str], str]:
    if not segment or not segment.strip():
        return [], " "
    if re.search(r"[\u4e00-\u9fff]", segment) and not re.search(r"\s", segment):
        return list(segment.strip()), ""
    return segment.split(), " "


def _strip_section_line_prefix(line: str) -> str:
    normalized = line
    changed = True
    while changed:
        changed = False
        for pattern in SECTION_LINE_PREFIX_PATTERNS:
            stripped = re.sub(pattern, "", normalized, count=1)
            if stripped != normalized:
                normalized = stripped
                changed = True
    return normalized


def _estimate_tokens(text: str) -> int:
    tokens = text.split()
    if tokens:
        return len(tokens)
    normalized = text.strip()
    if not normalized:
        return 0
    if re.search(r"[\u4e00-\u9fff]", normalized):
        return len(normalized)
    return 1


def _split_text(text: str, max_tokens: int) -> list[str]:
    if max_tokens <= 0:
        raise ValueError("max_tokens 必须大于 0")

    raw_chunks = [c.strip() for c in re.split(r"[。？！；;,，、\n\r]", text) if c.strip()]
    chunks = []
    current = []
    cur_tokens = 0
    for seg in raw_chunks:
        segment_tokens, joiner = _segment_tokens(seg)
        if not segment_tokens:
            continue

        # 长段落没有标点时，按 max_tokens 粒度切分，避免单段超限
        start = 0
        while start < len(segment_tokens):
            available = max_tokens - cur_tokens if current else max_tokens
            if available <= 0:
                chunks.append("；".join(current))
                current = []
                cur_tokens = 0
                available = max_tokens
            take = min(available, len(segment_tokens) - start)
            piece = "".join(segment_tokens[start:start + take]) if joiner == "" else " ".join(segment_tokens[start:start + take])
            current.append(piece)
            cur_tokens += take
            start += take

            if cur_tokens >= max_tokens:
                chunks.append("；".join(current))
                current = []
                cur_tokens = 0
    if current:
        chunks.append("；".join(current))
    return chunks


def _extract_sections(text: str) -> dict[str, str]:
    headers = {k: "" for k in SECTION_PATTERNS}
    lines = text.splitlines()
    current = "目标"
    for line in lines:
        line_stripped = line.strip()
        normalized_line = _strip_section_line_prefix(line_stripped)
        matched = None
        split_parts = re.split(r"[:：]", normalized_line, maxsplit=1)
        if len(split_parts) == 2:
            label = split_parts[0].strip()
            suffix = split_parts[1].strip()
            normalized = label.lower()
            matched = SECTION_KEY_MAP.get(normalized)
        else:
            matched_wrapped = False
            for open_ch, close_ch in (("【", "】"), ("(", ")"), ("[", "]")):
                if not normalized_line.startswith(open_ch):
                    continue
                close_index = normalized_line.find(close_ch, len(open_ch))
                if close_index <= len(open_ch):
                    continue
                label = normalized_line[len(open_ch):close_index].strip().lower()
                alias_section = SECTION_KEY_MAP.get(label)
                if alias_section:
                    matched = alias_section
                    suffix = normalized_line[close_index + len(close_ch):].strip()
                    if suffix.startswith(("：", ":")):
                        suffix = suffix[1:].strip()
                    matched_wrapped = True
                    break

            if not matched_wrapped:
                normalized = normalized_line.lower()
                suffix = ""
                for alias in sorted(SECTION_KEY_MAP, key=len, reverse=True):
                    if alias.isascii():
                        if not re.match(rf"^{re.escape(alias)}(?:\s|$)", normalized):
                            continue
                    if not normalized.startswith(alias):
                        continue
                    matched = SECTION_KEY_MAP[alias]
                    suffix = normalized_line[len(alias):].strip()
                    break
        if matched:
            current = matched
            if suffix:
                headers[current] += (suffix + " ")
        else:
            headers[current] += (line_stripped + " ")
    return {k: v.strip() for k, v in headers.items()}


def _score_complexity(sections: dict[str, str]) -> int:
    text_for_risk = (
        sections["目标"] + " " + sections["交付"] + " " + sections["验收"]
    )
    base = _estimate_tokens(text_for_risk)
    risk_terms = ["性能", "并发", "兼容", "回滚", "生产", "迁移", "重构", "兼容性"]
    penalty = sum(text_for_risk.count(t) for t in risk_terms)
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
        est_tokens = _estimate_tokens(chunk)
        checkpoints.append(Checkpoint(title, work, acceptance, rollback, risks, est_tokens))
    return checkpoints


def build_report(text: str, max_tokens: int = 120, no_risk: bool = False) -> dict:
    sections = _extract_sections(text)
    chunks = _split_text(text, max_tokens=max_tokens)
    checkpoints = _build_checkpoints(chunks, no_risk=no_risk)
    return {
        "schema_version": "1.0",
        "app": APP_NAME,
        "version": VERSION,
        "generated_at": _utc_timestamp(),
        "complexity": _score_complexity(sections),
        "summary": sections["目标"][:120] or "未识别到明确目标",
        "constraints": [x for x in [sections["约束"]] if x],
        "acceptance_targets": [x for x in [sections["验收"]] if x],
        "checkpoints": [asdict(c) for c in checkpoints],
    }


def _to_markdown(data: dict, include_risk: bool = True) -> str:
    lines = [
        "# 长任务优化结果",
        f"- 应用：{data.get('app', APP_NAME)}",
        f"- 版本：{data.get('version', VERSION)}",
        f"- 输出协议：{data.get('schema_version', '1.0')}",
        f"- 生成时间：{data['generated_at']}",
        f"- 复杂度：{data['complexity']}/100",
        f"- 目标摘要：{data['summary']}",
        f"- 估算阶段数：{len(data['checkpoints'])}",
        "",
    ]
    if include_risk:
        lines.extend([
            "## 风险点与建议",
            "- 先写清边界，尽量只改一件事",
            "- 每个阶段保留可回退点",
            "- 关键结果先做验收，再推进下一阶段",
            "",
        ])
    lines.append("## 分解计划")
    for idx, c in enumerate(data["checkpoints"], start=1):
        lines.append(f"### {idx}. {c['title']}")
        lines.append(f"- 预估 token：{c['est_tokens']}")
        lines.append("- 待办：")
        lines.extend([f"  - {w}" for w in c["work"]])
        lines.append("- 验收：")
        lines.extend([f"  - {a}" for a in c["acceptance"]])
        lines.append(f"- 回退点：{c['rollback']}")
        if c["risks"] and include_risk:
            lines.append("- 风险：")
            lines.extend([f"  - {r}" for r in c["risks"]])
        lines.append("")
    return "\n".join(lines)


def _status_payload() -> dict[str, str]:
    return {
        "app": APP_NAME,
        "version": VERSION,
        "python": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "generated_at": _utc_timestamp(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="将长任务按阶段拆解")
    parser.add_argument("--input", default=str(DEFAULT_SAMPLE_PATH), help="任务输入文件路径")
    parser.add_argument("--text", help="直接传入任务文本，优先级高于 --input")
    parser.add_argument("--max-tokens", type=int, default=120, help="每个阶段最大 token 估算")
    parser.add_argument("--format", choices=["md", "json"], default="md", help="输出格式")
    parser.add_argument("--no-risk", action="store_true", help="不输出风险提示")
    parser.add_argument("--out", help="将结果写入到指定文件")
    parser.add_argument("--version", action="store_true", help="输出版本并退出")
    parser.add_argument("--status", action="store_true", help="输出状态摘要并退出")
    args = parser.parse_args()

    if args.version:
        print(f"{APP_NAME} {VERSION}")
        return

    if args.status:
        print(json.dumps(_status_payload(), ensure_ascii=False, indent=2))
        return

    try:
        text = _load_input_text(args.input, args.text)
        report = build_report(text, max_tokens=args.max_tokens, no_risk=args.no_risk)
    except FileNotFoundError as exc:
        print(f"输入文件错误：{exc}", file=sys.stderr)
        raise SystemExit(2)
    except ValueError as exc:
        print(f"参数错误：{exc}", file=sys.stderr)
        raise SystemExit(2)

    if args.format == "json":
        output = json.dumps(report, ensure_ascii=False, indent=2)
    else:
        output = _to_markdown(report, include_risk=not args.no_risk)

    if args.out:
        out_path = _expand_path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            out_path.write_text(output, encoding="utf-8")
        except OSError as exc:
            print(f"输出文件错误：{exc}", file=sys.stderr)
            raise SystemExit(2)
    else:
        print(output)


if __name__ == "__main__":
    main()
