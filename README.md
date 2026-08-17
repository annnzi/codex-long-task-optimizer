# codex-long-task-optimizer

一句话价值：把一段“拍脑袋”长需求，立刻切成可执行的阶段任务。  
One-liner: Turn long, messy tasks into executable phase plans.

[![CI](https://github.com/annnzi/codex-long-task-optimizer/actions/workflows/ci.yml/badge.svg)](https://github.com/annnzi/codex-long-task-optimizer/actions/workflows/ci.yml)

## 这是一个什么工具

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

## 2 分钟接入（新用户友好版）

```bash
git clone https://github.com/annnzi/codex-long-task-optimizer.git
cd codex-long-task-optimizer

python -m venv .venv
# Windows PowerShell:
# .\.venv\Scripts\Activate.ps1
# macOS/Linux:
# source .venv/bin/activate

python -m pip install -e .
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
```

不用安装也能跑：

```bash
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
```

## 你只需要记住的几条

- `--input`：任务文本路径，默认 `examples/sample-task.txt`
- `--max-tokens`：单阶段预算，默认 `120`
- `--format`：`md`（默认）或 `json`
- `--no-risk`：隐藏风险段
- `--out`：生成文件
- `--version`：看版本

## 30 秒验收（最重要）

运行这条后，终端里看到“阶段/验收/回退点”就算接入成功：

```bash
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
```

期待看到的输出特征：

- 已按阶段拆解任务
- 每阶段带可执行项
- 包含验收标准
- 至少有一条风险提示（除非你用了 `--no-risk`）

## 一键命令清单

- `python -m src.long_task_optimizer --format md`
- `python -m src.long_task_optimizer --format json`
- `python -m src.long_task_optimizer --out reports/plan.md --format md`
- `python -m src.long_task_optimizer --max-tokens 180 --no-risk`
- `python -m pytest -q`

## 适配智能体 / Skill 接入

- Skill 定义：[`SKILL.md`](SKILL.md)
- 智能体使用手册：[`docs/USAGE_FOR_AGENTS.md`](docs/USAGE_FOR_AGENTS.md)
- 支持把长任务快速转成给 AI 的可执行任务结构化计划。

## 项目结构（极简）

- `src/long_task_optimizer.py`：核心代码
- `examples/sample-task.txt`：示例输入
- `tests/test_long_task_optimizer.py`：基础验证
- `docs/context/`：上下文（静态/动态）
- `docs/USAGE_FOR_AGENTS.md`：智能体使用手册
- `.github/workflows/ci.yml`：自动检查

## 快速接入项目的入口

- 仓库首页：`https://github.com/annnzi/codex-long-task-optimizer`
- 提 Issue：`https://github.com/annnzi/codex-long-task-optimizer/issues`
- 贡献说明：请先看 [CONTRIBUTING.md](CONTRIBUTING.md)
- 许可证：MIT，见 [LICENSE](LICENSE)。
