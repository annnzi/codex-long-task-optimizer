# 贡献指南

欢迎加入 `codex-long-task-optimizer`。

## 提交要求
1. 题目清晰：提交说明需写明“解决什么问题 + 预期效果”。
2. 保持可读性：优先可复现、可验证的变更。
3. 小步提交：单次 PR 只改一到两个点。
4. 风险标注：涉及算法规则变化必须附带风险与回退说明。

## 本地调试
- 修改 `src/long_task_optimizer.py`
- 运行示例：
  - `python -m src.long_task_optimizer --input examples/sample-task.txt --format json`
  - 检查输出可读性与分阶段结果

## 代码风格
- Python 使用标准库优先，不新增重依赖。
- 文案输出以中文为主，确保中文项目也能直接使用。

## 版本发布建议

1. 更新 `CHANGELOG.md`
2. 更新示例与 README 的相关示例
3. 提交时在提交信息中注明影响范围（如 `feat:`、`fix:`、`docs:`）
4. 发布后在 Issues 中公告迁移和使用方法
