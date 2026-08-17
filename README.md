# codex-long-task-optimizer

一个面向 Codex / 长任务协作场景的轻量 CLI 工具。  
目标是把「需求描述」稳定转成可执行计划：**阶段划分、验收项、回退点、风险点**，减少一次性长任务带来的偏差。

## 解决什么问题

- 避免长任务一次性下发导致执行顺序乱、验收困难的问题。
- 把任务说明中的「目标/范围/交付/约束/验收」内容落成可复用结构。
- 支持快速复制到 Codex 对话框、Issue / PR 备注、交接文档。

## 功能

- 自动识别文本中的关键字段（目标、范围、交付、约束、验收）
- 按 token 粗估（默认 120）切分为多个阶段
- 输出 Markdown 或 JSON
- 可选关闭风险段（`--no-risk`）
- 支持直接输出到文件（`--out`）
- 支持版本查看（`--version`）

## 快速开始

```bash
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
python -m src.long_task_optimizer --input examples/sample-task.txt --format json
python -m src.long_task_optimizer --input examples/sample-task.txt --out reports/plan.md --format md
python -m src.long_task_optimizer --version
```

### 参数说明

- `--input`：任务文本路径（默认 `examples/sample-task.txt`）
- `--max-tokens`：每个阶段最大 token 粗估，默认 `120`
- `--format`：`md`（默认）或 `json`
- `--no-risk`：不展示风险段
- `--out`：将输出写到文件
- `--version`：输出工具版本并退出

## 示例

```bash
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
```

输出为：

- 阶段列表
- 每阶段工作项
- 验收项
- 回退方式
- 风险提示

## 项目结构

- `src/long_task_optimizer.py`：核心解析与报告生成逻辑
- `examples/sample-task.txt`：示例任务文本
- `tests/test_long_task_optimizer.py`：基础测试
- `docs/context/`：上下文与运行状态记录
- `CHANGELOG.md`：版本变更记录
- `.github/workflows/ci.yml`：基础 CI（pytest）

## 开发

### 开发环境建议

- Python 3.9+
- 纯标准库，无额外运行时依赖

### 本地常用命令

- `python -m src.long_task_optimizer --input examples/sample-task.txt --format json`
- `python -m pytest -q`

## 里程碑（运营节奏）

1. **MVP 已上线**：文本分阶段输出、风险与回退点（v0.1.x）
2. **可运营化**：贡献规范、模板、Issue 模板（v0.2）
3. **生态接入**：增加与 CI/任务追踪系统的输出映射（v0.3）

## 贡献

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 后提交。

## 许可证

MIT，详见 [LICENSE](LICENSE)。

## 维护者说明（给申请活动准备）

如果你准备申请 OpenAI 的开源维护者计划，请优先准备：

- `README` 的真实使用价值（解决场景）
- 公开项目历史（commit / issue / release）
- 持续维护动作（每周至少更新一次）
- 明确的可量化价值点（stars、依赖、实际使用）
