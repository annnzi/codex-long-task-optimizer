from __future__ import annotations

import sys
import io
import json
from pathlib import Path

import pytest

from src.long_task_optimizer import _build_checkpoints, build_report, _extract_sections, _split_text, _score_complexity, _to_markdown


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


def test_extract_sections_supports_uppercase_english_labels():
    text = "\n".join([
        "GOAL: Launch project",
        "SCOPE: Alpha",
        "DELIVERABLE: one report",
        "CONSTRAINTS: no network",
        "ACCEPTANCE: tests pass",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "Launch project"
    assert sections["范围"] == "Alpha"
    assert sections["交付"] == "one report"
    assert sections["约束"] == "no network"
    assert sections["验收"] == "tests pass"


def test_extract_sections_supports_prefixed_english_labels():
    text = "\n".join([
        "GOALS: Launch launch",
        "OUTPUTS: one artifact",
        "CONSTRAINTS: no network",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "Launch launch"
    assert sections["交付"] == "one artifact"
    assert sections["约束"] == "no network"


def test_extract_sections_supports_bulleted_list_labels():
    text = "\n".join([
        "- 目标：完善项目可读性",
        "* 范围：增强接入指引",
        "• 交付：可复用的输出模板",
        "1. 验收：输出可直接交接",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "完善项目可读性"
    assert sections["范围"] == "增强接入指引"
    assert sections["交付"] == "可复用的输出模板"
    assert sections["验收"] == "输出可直接交接"


def test_extract_sections_supports_numbered_english_labels():
    text = "\n".join([
        "1. GOAL: improve parser compatibility",
        "2) SCOPE: support bullets",
        "3. CONSTRAINTS: keep no deps",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "improve parser compatibility"
    assert sections["范围"] == "support bullets"
    assert sections["约束"] == "keep no deps"


def test_extract_sections_supports_mixed_number_and_checkbox_prefixes():
    text = "\n".join([
        "1. [x] 目标：支持清单复选框组合前缀",
        "2) [ ] Scope: handle numbered checklist prefixes",
        "+ [x] 交付：输出更通用",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "支持清单复选框组合前缀"
    assert sections["范围"] == "handle numbered checklist prefixes"
    assert sections["交付"] == "输出更通用"


def test_extract_sections_supports_markdown_headers_with_colon():
    text = "\n".join([
        "## 目标：梳理接入文档",
        "### 范围：兼容常见复制格式",
        "#### 交付：可直接执行清单",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "梳理接入文档"
    assert sections["范围"] == "兼容常见复制格式"
    assert sections["交付"] == "可直接执行清单"


def test_extract_sections_supports_markdown_headers_without_colon():
    text = "\n".join([
        "### GOAL define stable parsing",
        "### SCOPE support markdown headers",
        "#### OUTPUTS outputs ready",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "define stable parsing"
    assert sections["范围"] == "support markdown headers"
    assert sections["交付"] == "outputs ready"


def test_extract_sections_supports_markdown_task_list_labels():
    text = "\n".join([
        "- [ ] 目标：完成任务清单兼容",
        "- [x] 范围：支持 checkbox 样式",
        "- [X] 交付：输出可复用清单",
        "- [ ] 验收：可直接交付",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "完成任务清单兼容"
    assert sections["范围"] == "支持 checkbox 样式"
    assert sections["交付"] == "输出可复用清单"
    assert sections["验收"] == "可直接交付"


def test_extract_sections_supports_fullwidth_numbered_prefixes():
    text = "\n".join([
        "1）目标：补充中文序号兼容",
        "（2）范围：适配会议纪要常见标号",
        "3）交付：可执行任务模板",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "补充中文序号兼容"
    assert sections["范围"] == "适配会议纪要常见标号"
    assert sections["交付"] == "可执行任务模板"


def test_extract_sections_supports_inline_keyword_without_delimiter():
    text = "\n".join([
        "目标完成一个发布流程",
        "范围覆盖 5 个渠道",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "完成一个发布流程"
    assert sections["范围"] == "覆盖 5 个渠道"


def test_extract_sections_supports_wrapped_labels():
    text = "\n".join([
        "【目标】发布一个季度优化版本",
        "【范围】兼容清单式输入",
        "【交付】可复用的输出模板",
        "【验收】任务可直接执行",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "发布一个季度优化版本"
    assert sections["范围"] == "兼容清单式输入"
    assert sections["交付"] == "可复用的输出模板"
    assert sections["验收"] == "任务可直接执行"


def test_extract_sections_supports_wrapped_labels_with_delimiter():
    text = "\n".join([
        "【目标】：输出更强的解析容错",
        "(范围) 发布流程回归验证",
        "[验收]：覆盖 10 个关键测试用例",
    ])
    sections = _extract_sections(text)
    assert sections["目标"] == "输出更强的解析容错"
    assert sections["范围"] == "发布流程回归验证"
    assert sections["验收"] == "覆盖 10 个关键测试用例"


def test_extract_sections_ascii_prefix_requires_boundary():
    text = "\n".join([
        "范围：接口稳定性优化",
        "goalpost：不应误识别为目标标签",
        "验收：接口可验收",
    ])
    sections = _extract_sections(text)
    assert sections["范围"] == "接口稳定性优化 goalpost：不应误识别为目标标签"
    assert sections["验收"] == "接口可验收"


def test_build_report_minimum_shape(tmp_path: Path):
    task = tmp_path / "t.txt"
    task.write_text("目标：完成一次长任务拆解")
    report = build_report(task.read_text(), max_tokens=5, no_risk=True)
    assert "generated_at" in report
    assert "checkpoints" in report
    assert isinstance(report["checkpoints"], list)
    assert isinstance(report["checkpoints"][0]["work"], list)


def test_build_checkpoints_estimates_tokens_with_non_ascii_chunks():
    checkpoints = _build_checkpoints(["这是中文测试文本"], no_risk=True)
    assert len(checkpoints) == 1
    assert checkpoints[0].est_tokens == 7


def test_version_constant_exists():
    from src import __version__

    assert isinstance(__version__, str)
    assert __version__


def test_split_text_splits_long_text_without_punctuation():
    text = "alpha beta gamma delta epsilon zeta eta theta"
    chunks = _split_text(text, max_tokens=3)
    assert chunks == ["alpha beta gamma", "delta epsilon zeta", "theta"]


def test_split_text_handles_long_chinese_without_spaces():
    text = "这是一个中文无空格的长文本用于验证按字符切片"
    chunks = _split_text(text, max_tokens=7)
    assert all(len(c) <= 7 for c in chunks)
    assert "".join(chunks) == text


def test_split_text_splits_on_comma_and_delimiters():
    text = "这是第一阶段，接着第二阶段，最终落地"
    chunks = _split_text(text, max_tokens=5)
    assert chunks == ["这是第一阶段", "接着第二阶段", "最终落地"]


def test_status_payload_contains_version():
    from src.long_task_optimizer import _status_payload
    from src import __version__

    payload = _status_payload()
    assert payload["app"] == "codex-long-task-optimizer"
    assert payload["version"] == __version__
    assert "generated_at" in payload


def test_build_report_defaults_when_empty_input():
    report = build_report("", max_tokens=5, no_risk=True)
    assert report["summary"] == "未识别到明确目标"
    assert report["checkpoints"] == []


def test_build_report_schema_keys():
    report = build_report("目标：发布一个新版本\n交付：稳定输出", max_tokens=10, no_risk=True)
    expected = {"generated_at", "complexity", "summary", "constraints", "acceptance_targets", "checkpoints"}
    assert expected.issubset(set(report))
    assert isinstance(report["checkpoints"], list)


def test_score_complexity_penalty_increases_with_risk_terms():
    normal = {
        "目标": "发布一个自动化长任务拆解工具",
        "交付": "生成稳定的阶段计划和验收标准",
        "验收": "通过验收测试",
    }
    risky = {
        "目标": "处理高并发兼容问题",
        "交付": "发布兼容性重构方案并进行性能回归",
        "验收": "验证生产迁移和回滚方案",
    }
    assert _score_complexity(risky) > _score_complexity(normal)


def test_score_complexity_estimates_chinese_without_spaces():
    report = build_report(
        "目标：版本发布与回归验证\n交付：上线无歧义步骤文档\n验收：通过验收检查表",
        max_tokens=20,
        no_risk=True,
    )
    assert report["complexity"] >= 20


def test_no_risk_flag_removes_risks():
    report = build_report("GOAL: Build stable pipeline\nDELIVERABLE: deliverable\nACCEPTANCE: pass", max_tokens=20, no_risk=True)
    assert all(len(c["risks"]) == 0 for c in report["checkpoints"])


def test_to_markdown_no_risk_hides_risk_notes():
    report = build_report("目标：梳理一个稳定发布流程\n验收：可执行计划", max_tokens=6, no_risk=True)
    markdown = _to_markdown(report, include_risk=False)
    assert "- 风险：" not in markdown
    assert "## 风险点与建议" not in markdown


def test_main_accepts_text_argument(monkeypatch, capsys):
    from src.long_task_optimizer import main

    monkeypatch.setattr(sys, "argv", [
        "codex-long-task-optimizer",
        "--text",
        "目标：直接传文本\n验收：可直接验收",
        "--format",
        "json",
        "--no-risk",
    ])
    main()
    data = json.loads(capsys.readouterr().out)
    assert data["checkpoints"]


def test_main_accepts_nested_output_dir(monkeypatch, tmp_path):
    from src.long_task_optimizer import main

    out_file = tmp_path / "nested" / "artifacts" / "plan.json"
    monkeypatch.setattr(sys, "argv", [
        "codex-long-task-optimizer",
        "--text",
        "目标：生成输出目录\n验收：可追踪",
        "--format",
        "json",
        "--out",
        str(out_file),
    ])
    main()
    assert out_file.exists()
    assert out_file.parent.exists()


def test_main_input_supports_tilde_expansion(monkeypatch, tmp_path, capsys):
    from src.long_task_optimizer import main

    task = tmp_path / "tilde-task.txt"
    task.write_text("目标：路径展开\n验收：可直接执行")
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "codex-long-task-optimizer",
            "--input",
            "~/tilde-task.txt",
            "--format",
            "json",
            "--no-risk",
        ],
    )
    main()
    data = json.loads(capsys.readouterr().out)
    assert data["summary"].startswith("路径展开")


def test_main_accepts_stdin_input(monkeypatch, capsys):
    from src.long_task_optimizer import main

    monkeypatch.setattr(
        sys,
        "stdin",
        io.StringIO("目标：STDIN输入任务\n交付：可用计划"),
    )
    monkeypatch.setattr(sys, "argv", [
        "codex-long-task-optimizer",
        "--input",
        "-",
        "--format",
        "json",
        "--no-risk",
    ])
    main()
    data = json.loads(capsys.readouterr().out)
    assert data["checkpoints"]


def test_main_accepts_stdin_input_with_padding_whitespace(monkeypatch, capsys):
    from src.long_task_optimizer import main

    monkeypatch.setattr(
        sys,
        "stdin",
        io.StringIO("   目标：去除空白\n验收：可直接使用   "),
    )
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "codex-long-task-optimizer",
            "--input",
            "-",
            "--format",
            "json",
            "--no-risk",
        ],
    )
    main()
    data = json.loads(capsys.readouterr().out)
    assert data["summary"].startswith("去除空白")


def test_main_text_input_takes_precedence(monkeypatch, capsys):
    from src.long_task_optimizer import main

    monkeypatch.setattr(sys, "argv", [
        "codex-long-task-optimizer",
        "--input",
        "C:/does/not/exist/any-task.txt",
        "--text",
        "目标：文本优先策略\n验收：文本可直接使用",
        "--format",
        "json",
        "--no-risk",
    ])
    main()
    data = json.loads(capsys.readouterr().out)
    assert data["summary"].startswith("文本优先策略")


def test_main_handles_empty_text_input(monkeypatch, capsys):
    from src.long_task_optimizer import main

    monkeypatch.setattr(sys, "argv", [
        "codex-long-task-optimizer",
        "--text",
        "   ",
        "--format",
        "json",
    ])
    with pytest.raises(SystemExit) as excinfo:
        main()
    assert excinfo.value.code == 2
    assert "输入内容不能为空" in capsys.readouterr().err


def test_main_handles_missing_input(monkeypatch, capsys):
    from src.long_task_optimizer import main

    missing = "C:/Users/19967/Documents/搜索/codex-long-task-optimizer/does-not-exist.txt"
    monkeypatch.setattr(sys, "argv", ["codex-long-task-optimizer", "--input", missing, "--no-risk"])
    with pytest.raises(SystemExit) as excinfo:
        main()
    assert excinfo.value.code == 2
    assert "输入文件错误" in capsys.readouterr().err


def test_main_handles_invalid_max_tokens(monkeypatch, tmp_path, capsys):
    from src.long_task_optimizer import main

    task = tmp_path / "task.txt"
    task.write_text("目标：测试")
    monkeypatch.setattr(
        sys,
        "argv",
        ["codex-long-task-optimizer", "--input", str(task), "--max-tokens", "0", "--no-risk"],
    )
    with pytest.raises(SystemExit) as excinfo:
        main()
    assert excinfo.value.code == 2
    assert "参数错误" in capsys.readouterr().err
