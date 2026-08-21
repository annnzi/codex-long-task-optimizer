from datetime import datetime

from src import __version__
from src.long_task_optimizer import APP_NAME, _to_markdown, build_report


def test_json_report_is_self_describing() -> None:
    report = build_report("目标：验证结构化计划元数据")

    assert report["schema_version"] == "1.0"
    assert report["app"] == APP_NAME
    assert report["version"] == __version__
    assert datetime.fromisoformat(report["generated_at"].replace("Z", "+00:00")).tzinfo is not None

    markdown = _to_markdown(report)
    assert f"- 版本：{__version__}" in markdown
    assert "- 输出协议：1.0" in markdown
