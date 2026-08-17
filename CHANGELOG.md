# CHANGELOG

## Unreleased

- Pending: release roadmap for v0.2

## v0.1.4 - 2026-08-17

- 添加 `SKILL.md`，定义可供其他智能体复用的能力边界与调用参数。
- 添加 `docs/USAGE_FOR_AGENTS.md`，提供智能体接入模板与失败处理建议。
- README 新增“技能接入”入口与双语可读说明。
- 更新项目版本标识为 `0.1.4`。

## v0.1.1 - 2026-08-17

- 增加 `--version`、`--out` 参数
- 优化字段解析：支持 `目标/scope` 等别名
- 改进切分参数校验，避免 0/负数导致异常行为
- 文档更新：README 与贡献流程补充运营节奏

## v0.1.0 - 2026-08-14

- 首次发布 MVP：任务文本分阶段输出（Markdown/JSON）
- 引入风险与回退建议
- 完成基础 pytest 用例
