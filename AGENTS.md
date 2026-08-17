# AGENTS

## 项目核心目标
- 维持 `codex-long-task-optimizer` 为一个轻量的 Python CLI 工具：将长任务文本拆解为可执行阶段。
- 展示名：`Task optimizer for long tasks (Agentic & Codex workflows)`。

## 目录和模块边界
- `src/long_task_optimizer.py`：核心执行逻辑与入口。
- `examples/sample-task.txt`：默认示例输入模板。
- `README.md`、`CONTRIBUTING.md`、`LICENSE`：项目说明与协作约定。
- `docs/context/PROJECT_STATIC.md`：项目长期稳定上下文（初始化后优先复用）。
- `docs/context/PROJECT_STATE.md`：动态状态（任务/变更/报错/运行结果），按任务更新。
- `docs/context` 仅用于上下文与执行记录，不放业务源码。

## 编码规范
- Python 优先使用标准库，避免新增外部依赖。
- UTF-8 编码，函数与变量命名可读、中文输出要清晰。
- 每次修改尽量小步提交，保持可追溯的阶段性能力。
- 优先优化“别人能否快速接入”和“维护节奏是否可见”。

## 测试、格式化和检查命令
- 基本可执行性检查：  
  `python -m src.long_task_optimizer --input examples/sample-task.txt --format json`
- 基本可读性检查：  
  `python -m src.long_task_optimizer --input examples/sample-task.txt --format md`
- 自动化测试：  
  `python -m pytest -q`
- 本地 CI 配置：`.github/workflows/ci.yml`（Python 3.11，Push/PR on main）。

## 禁止事项
- 禁止在任务间重复扫描全仓并重新推导已确认稳定的上下文。
- 禁止基于未核验信息做版本/行为断言。
- 未经确认不修改与任务目标无关的目录/脚本。
- 禁止把完整日志、超长终端输出或历史测试结果写进静态上下文。

## 任务完成标准
- 核心 CLI 功能可按 `--input/--format/--max-tokens/--no-risk` 运行。
- `AGENTS.md`、`docs/context/PROJECT_STATIC.md`、`docs/context/PROJECT_STATE.md` 必须与实际代码一致。
- 每次任务开始输出一行：  
  `上下文：复用[...]；新增[...]；跳过[...]。`
- 仅在出现动态变更/重新验证需求或跳过可能相关模块时才输出该行；否则可不重复报告。
- 不展开冗长解释，仅列关键项目。

## 上下文复用规则（推荐执行）
- `PROJECT_STATIC.md` 作为默认复用层：在会话开始时优先使用。
- 每次任务前声明：  
  - 本次复用的静态上下文清单；  
  - 新读取的动态文件/日志/测试输出；  
  - 与当前任务无直接关系且非依赖项的可跳过项。
- “不重复读取”是默认策略，不是绝对禁令：  
  - 与当前任务不相关、且长期未变的信息可跳过；  
  - 与任务相关的依赖链文件，即使未变，也可以按需读取以保证正确性。
- 动态上下文更新条件：新需求、代码修改、新文件、报错日志、测试结果、运行/部署结果。
- 若信息无法从仓库源码验证，必须标注为 `待验证`。

### 长期版上下文复用规则（最终版）
- 先复用：`AGENTS.md`、`docs/context/PROJECT_STATIC.md`、`docs/context/PROJECT_STATE.md` 中已确认的静态信息。
- 再读取：本次任务相关文件（含未改但依赖关系相关文件）和新日志/报错/验证输出。
- 仅在这些源文件有变化后更新静态快照：
  - `src/long_task_optimizer.py`
  - `pyproject.toml`
  - `docs/context/PROJECT_STATIC.md`
  - 业务边界与长期约束文档
- 静态信息与源代码冲突时，以当前源代码与配置为准；冲突部分需标记 `待验证` 并在下次任务修复。

## 维护执行纪律（挤牙膏式）
- 以「小步提交」为主：每次改动聚焦一个独立点，避免一次改很多无关内容。
- 按时间窗口推进：优先在同一窗口完成本地连续优化，窗口结束后统一提交。
- 公开仓库节奏保持可见：不追求一次推满，保留 2 小时粒度的进展提交。
