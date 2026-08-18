# Skill: Task optimizer for long tasks (Agentic & Codex workflows)

## 目标 / Purpose
- 为其它智能体提供“长任务结构化切分”为可执行阶段计划的通用能力。
- Convert long natural-language tasks into executable phases with checkpoints, acceptance criteria, rollback notes, and risk points.

## 适用场景 / Use cases
- 把一个长需求按阶段拆解成可执行工作项。
- 为代码/内容任务生成复用的交付大纲。
- 在 Issue、PR、交接文档中自动产出可审阅计划。

## 输入 / Inputs
### 标准输入文件
- `--input`：任务文本路径（默认 `examples/sample-task.txt`）。
- `--text`：直接传入任务文本（优先级高于 `--input`）。
- `--input -`：从标准输入读取任务文本。
- 安装后命令别名（任一可用）：`task-optimizer`、`agentic-task-optimizer`、`codex-long-task-optimizer`。

### 推荐调用方式
- 文本文件输入：  
  `python -m src.long_task_optimizer --input <file> --format <md|json>`
- 直接文本输入：  
  `python -m src.long_task_optimizer --text "目标：..." --format <md|json>`
- 管道输入：  
  `echo "目标：..." | python -m src.long_task_optimizer --input - --format json`
- 可选参数：  
  `--max-tokens`、`--no-risk`、`--out`、`--status`、`--version`

## 输出 / Outputs
- Markdown：阶段标题、每阶段工作项、验收标准、回退点、风险提示。
- JSON：同样结构化字段，便于模型和脚本解析。

## 命令映射 / Command mapping
- CLI：`python -m src.long_task_optimizer [--input <path>] [--text <raw>] --format <md|json> [--max-tokens N] [--no-risk] [--out <path>]`
- 安装后脚本：`task-optimizer --text ...`（推荐）  
  `agentic-task-optimizer`、`codex-long-task-optimizer` 可并存使用。
- 项目展示名：`Task optimizer for long tasks (Agentic & Codex workflows)`（对应 README 与主页文案）。

## 关键约束 / Constraints
- 不新增额外外部依赖（默认标准库优先）。
- 输入为任务文本，不执行联网检索。
- 输出目标是“可复用计划”，不是自动执行代码。

## 质量要求 / Quality check
- 同一任务建议同时验证一次：
  - `--format md`
  - `--format json`
- 若格式不同，字段含义需保持一致。

## 错误与回退 / Error handling
- 参数缺失/无效：返回 CLI 说明和非零码。
- 解析失败：给出可读错误并保持可复用结构（至少输出失败位置）。
- 对外部智能体建议将失败结果记录为“未完成 + 重试原因”。

## 快速模板（可直接贴给智能体）
- 目标：把以下任务文本按阶段拆解为可执行清单。
- 输入：`--text`（推荐）或任务文件 `--input`。
- 输出要求：`format=md`，包含验收、回退、风险。

## 版本与边界 / Versioning and boundary
- 文档版本更新同步参考 `CHANGELOG.md` 与 `pyproject.toml`。
