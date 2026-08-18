# Task optimizer for long tasks (Agentic & Codex workflows) / 智能体使用手册

## 一句话能力 / One-line capability
- 输入任务文本，输出“阶段化执行计划”（含验收、回退、风险）。

## 推荐调用方式 / Recommended call pattern
- 若你有任务文本文件：  
  `python -m src.long_task_optimizer --input <file> --format md`
- 若你想用更大众的入口脚本：  
  `task-optimizer --text "<任务文本>" --format md`
- 若你有原始文本字符串：直接使用 `--text "..."`。
- 若你在 pipeline/脚本里：使用 `--input -` 从标准输入读取。

## 标准参数 / Standard params
- `--input <path>`：任务输入文件路径（默认 `examples/sample-task.txt`）
- `--text <text>`：直接输入任务文本，优先于 `--input`
- `--input -`：从标准输入读取任务文本
- `--max-tokens <int>`：阶段上限，默认 `120`
- `--format <md|json>`
- `--no-risk`：关闭风险提示（保留回退段；Markdown 输出不显示风险点小节与风险项）
- `--status`：输出 `app/version/python/generated_at` 状态快照
- `--out <path>`：写入文件
- `--version`：查看版本

## 输出契约 / Output contract
- Markdown 模式：
  - 阶段顺序
  - 每阶段工作项
  - 验收标准
  - 回退方式
  - 风险提示
- JSON 模式：
  - `generated_at`：生成时间
  - `complexity`：复杂度评分（0-100）
  - `summary`：目标摘要
  - `constraints`：约束数组
  - `acceptance_targets`：验收目标数组
  - `checkpoints`：阶段列表（title/work/acceptance/rollback/risks/est_tokens）

## 兼容性 / Compatibility
- Python 3.9+，无重依赖
- 适合嵌入到 Issue 生成、PR 说明、任务交接流程

## 调用示例（最小） / Minimal example
```bash
python -m src.long_task_optimizer --input examples/sample-task.txt --format json
```

## 失败处理 / Failure handling
- 遇到解析失败：保留原始输入、重试前先降低 `--max-tokens`。
- 遇到参数错误：重置为默认值再重试。
- 遇到空输出：检查输入文件是否为空或字段是否可识别。

## 输出交付示例给调用者 / Output handoff template
- 任务目标：...
- 拆分阶段：
  - Phase 1: ...
  - Phase 2: ...
- 验收标准：...
- 风险与回退：...
