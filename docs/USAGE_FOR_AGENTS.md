# codex-long-task-optimizer for Agents / 智能体使用手册

## 一句话能力 / One-line capability
- 输入任务文本，输出“阶段化执行计划”（含验收、回退、风险）。

## 推荐调用方式 / Recommended call pattern
- 若你有任务文本文件：  
  `python -m src.long_task_optimizer --input <file> --format md`
- 若你有原始文本字符串：请先写入临时文件再调用，或在上游框架中封装 `task_text` 为文件。

## 标准参数 / Standard params
- `--input <path>`：任务输入文件路径（默认 `examples/sample-task.txt`）
- `--max-tokens <int>`：阶段上限，默认 `120`
- `--format <md|json>`
- `--no-risk`：关闭风险/回退段
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
  - `tasks` / `phases` / `acceptance` / `rollback` / `risks`

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
