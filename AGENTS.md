# AGENTS

## 项目核心目标
- 维持 `codex-long-task-optimizer` 为一个轻量的 Python CLI 工具：将长任务文本拆解为可执行阶段。

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

## 测试、格式化和检查命令
- 基本可执行性检查：  
  `python -m src.long_task_optimizer --input examples/sample-task.txt --format json`
- 基本可读性检查：  
  `python -m src.long_task_optimizer --input examples/sample-task.txt --format md`
- 自动化测试：  
  `python -m pytest -q`
- 本地 CI 配置：`.github/workflows/ci.yml`（Python 3.11，Push/PR on main）。

## 禁止事项
- 禁止在任务间重复做全仓库扫描或重复推导稳定上下文。
- 禁止基于未核验信息做版本/行为断言。
- 未经确认不修改与任务目标无关的目录/脚本。

## 任务完成标准
- 核心 CLI 功能可按 `--input/--format/--max-tokens/--no-risk` 运行。
- `AGENTS.md`、`docs/context/PROJECT_STATIC.md`、`docs/context/PROJECT_STATE.md` 必须与实际代码一致。
- 每次任务开始先说明：复用了哪些静态上下文、重新读取了哪些动态信息、哪些可跳过。

## 上下文复用规则
- 复用规则先行：`PROJECT_STATIC.md` 中内容默认长期有效。
- 仅在以下情况更新动态状态：新需求、代码修改、报错日志、测试结果、运行或部署结果。
- 若信息无法从仓库源码验证，必须标注为 `待验证`。

## 维护执行纪律（挤牙膏式）
- 以「小步提交」为主：每次改动聚焦一个独立点，避免一次改很多无关内容。
- 按时间窗口推进：优先在同一窗口完成本地连续优化，窗口结束后统一提交。
- 公开仓库节奏保持可见：不追求一次推满，保留 2 小时粒度的进展提交。
