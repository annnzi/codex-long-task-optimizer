from __future__ import annotations

from pathlib import Path

from src.long_task_optimizer import build_report, _extract_sections, _split_text


def test_split_text_respects_limit():
    text = "a b c d e f g h i j"
    chunks = _split_text(text, max_tokens=3)
    assert len(chunks) >= 3
    assert all(len(c.split()) <= 3 for c in chunks)


def test_extract_sections_parses_structure():
    text = "\n".join([
        "目标：完成X",
        "范围：范围A",
        "交付：输出A",
        "约束：不改Y",
        "验收：通过Z",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "完成X"
    assert sections["范围"] == "范围A"
    assert sections["交付"] == "输出A"
    assert sections["约束"] == "不改Y"
    assert sections["验收"] == "通过Z"


def test_build_report_minimum_shape(tmp_path: Path):
    task = tmp_path / "t.txt"
    task.write_text("目标：完成一次长任务拆解")
    report = build_report(task.read_text(), max_tokens=5, no_risk=True)
    assert "generated_at" in report
    assert "checkpoints" in report
    assert isinstance(report["checkpoints"], list)
    assert isinstance(report["checkpoints"][0]["work"], list)


def test_version_constant_exists():
    from src import __version__

    assert isinstance(__version__, str)
    assert __version__
