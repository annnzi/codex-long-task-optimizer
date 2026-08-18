# Task optimizer for long tasks (Agentic & Codex Workflows)
## (codex-long-task-optimizer)

一句话价值：把一段“拍脑袋”长需求，立刻切成可执行的阶段任务。  
One-liner: Turn long, messy task descriptions into executable phase plans.

[![CI](https://github.com/annnzi/codex-long-task-optimizer/actions/workflows/ci.yml/badge.svg)](https://github.com/annnzi/codex-long-task-optimizer/actions/workflows/ci.yml)

## 这是一个什么工具 / What is this

### 中文

这个仓库不是复杂框架，只有一套核心逻辑：  
- 自动识别任务里的目标、范围、交付、约束、验收  
- 自动切成阶段，附带回退和风险点  
- 支持 Markdown / JSON 两种输出  
- 适合直接贴给 Codex、Issue、PR 或交接文档  

如果你经常遇到这种问题：  
- 需求太长，目标散了  
- 执行顺序乱了  
- 交付节点说不清  
- 最后验收靠猜  

这个工具的目的就是帮你把混乱变成“可执行清单”。

### English

This repository is a lightweight utility (not a heavy framework):  
- Extracts task fields from text: goals, scope, deliverables, constraints, acceptance  
- Splits work into phases with rollback points and risk notes  
- Outputs in Markdown or JSON  
- Ready to paste into Codex, Issues, PRs, and handover docs  

Common pain points this helps with:  
- Requirements are too long and objectives are scattered  
- Execution order is unclear  
- Delivery checkpoints are hard to define  
- Acceptance depends on guesswork at the end  

The goal is to convert messy long tasks into an **actionable checklist**.

## 2 分钟接入 / 2-minute setup (new-user friendly)

```bash
git clone https://github.com/annnzi/codex-long-task-optimizer.git
cd codex-long-task-optimizer

python -m venv .venv
# Windows PowerShell:
# .\.venv\Scripts\Activate.ps1
# macOS/Linux:
# source .venv/bin/activate

python -m pip install -e .
task-optimizer --text "目标：验证首次启动" --format md
codex-long-task-optimizer --text "目标：验证首次启动" --format md
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
```

不用安装也能跑 / Run without install:

```bash
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
python -m src.long_task_optimizer --text "目标：发布一个长任务版本" --format json
```

## 你只需要记住的几条 / Quick options

- `--input`：任务文本路径，默认 `examples/sample-task.txt`  
  `--input`: task text file, default `examples/sample-task.txt`
- `--text`：直接传入任务文本（优先级高于 `--input`）  
  `--text`: pass raw task text directly (takes priority over `--input`).
- `--input -`：从标准输入读取任务文本（可用于 pipeline）  
  `--input -`: read task text from stdin (pipeline input supported).
- `--max-tokens`：单阶段预算，默认 `120`  
  `--max-tokens`: budget per phase, default `120`
- `--format`：`md`（默认）或 `json`  
  `--format`: `md` (default) or `json`
- `--no-risk`：隐藏风险提示（保留回退段；Markdown 下不显示风险小节和风险项）  
  `--no-risk`: hide risk notes, keep rollback section; markdown output omits risk sections
- `--status`：输出版本与运行环境摘要（`version/app/python/generated_at`）  
  `--status`: output status summary (`version/app/python/generated_at`)
- `--out`：生成文件  
  `--out`: output to file
- `--version`：看版本  
  `--version`: print version

## 30 秒验收（最重要）/ 30-second verification

运行这条后，终端里看到“阶段/验收/回退点”就算接入成功：  
If this command prints phases, acceptance criteria, and rollback points, you are good:

```bash
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
```

期待看到的输出特征：  
Expected output signals:

- 已按阶段拆解任务 / Task split into phases
- 每阶段带可执行项 / Actionable items in each phase
- 包含验收标准 / Clear acceptance criteria
- 至少有一条风险提示（除非你用了 `--no-risk`）/ At least one risk note unless `--no-risk` is set

## 一键命令清单 / One-command list

- `task-optimizer --format md`
- `agentic-task-optimizer --format md`
- `python -m src.long_task_optimizer --format md`
- `python -m src.long_task_optimizer --format json`
- `python -m src.long_task_optimizer --text "目标：发布一个长任务拆解计划" --format json`
- `codex-long-task-optimizer --text "目标：发布一个长任务拆解计划" --format json`
- `python -m src.long_task_optimizer --out reports/plan.md --format md`
- `python -m src.long_task_optimizer --max-tokens 180 --no-risk`
- `python -m pytest -q`

## 示例 / Quick example

### 示例输入 / Input sample

`examples/sample-task.txt`

```text
目标：完成一个长任务拆解工具的迭代发布
范围：支持 3 个阶段输出和一个回退点
交付：输出包含验收标准的 Markdown 报告
约束：不引入第三方依赖
验收：每个阶段可直接执行，并能用于 PR 说明
```

### 示例输出（Markdown） / Sample output (Markdown)

```md
## Phase 1
- 可执行项：梳理任务目标与边界
- 验收：目标、范围、交付、约束、验收提取完整
- 回退点：保留原始任务文本版本
- 风险：字段识别可能遗漏边界语句
```

### 示例输出（JSON） / Sample output (JSON)

```json
{
  "generated_at": "2026-08-17T16:00:00Z",
  "complexity": 29,
  "summary": "完成一个长任务拆解工具的迭代发布",
  "constraints": ["不引入第三方依赖"],
  "acceptance_targets": ["每个阶段可直接执行，并能用于 PR 说明"],
  "checkpoints": [
    {
      "title": "阶段 1：澄清边界",
      "work": [
        "完成：完成一个长任务拆解工具的迭代发布；范围：支持3个阶段输出和一个回退点；交付：输出包含验收标准的 Markdown 报告",
        "产出：阶段性结果文件或验证截图",
        "检查：确认前置条件与依赖可满足"
      ],
      "acceptance": [
        "本阶段输出可独立验证",
        "无阻塞性高风险变更（如可回避则延后）"
      ],
      "rollback": "将本阶段变更回退到上一次可验证提交",
      "risks": [
        "需求边界不完整导致返工",
        "外部依赖文档不足导致时间偏差"
      ],
      "est_tokens": 17
    }
  ]
}
```

## 适配智能体 / Skill integration

- Skill definition: [`SKILL.md`](SKILL.md)
- Agent usage handbook: [`docs/USAGE_FOR_AGENTS.md`](docs/USAGE_FOR_AGENTS.md)
- 用于把长任务快速转成 AI 可执行的结构化计划。/ Convert long tasks into structured, AI-usable execution plans quickly.

## 项目结构（极简）/ Project structure (minimal)

- `src/long_task_optimizer.py`：核心代码 / core logic
- `examples/sample-task.txt`：示例输入 / sample input
- `tests/test_long_task_optimizer.py`：基础验证 / smoke tests
- `docs/context/`：上下文（静态/动态）/ context snapshots (static/dynamic)
- `docs/USAGE_FOR_AGENTS.md`：智能体使用手册 / agent usage handbook
- `.github/workflows/ci.yml`：自动检查 / CI checks

## 快速接入项目的入口 / Entry points

- 仓库首页 / Repo page: `https://github.com/annnzi/codex-long-task-optimizer`
- 提 Issue / Report issues: `https://github.com/annnzi/codex-long-task-optimizer/issues`
- 贡献说明 / Contributing guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- 许可证 / License: MIT, [LICENSE](LICENSE)



