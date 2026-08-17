# PROJECT_STATIC（静态上下文）

最后验证：2026-08-17（按需同步）

## 项目范围与目标
- `Task optimizer for long tasks (Agentic & Codex workflows)`（技术名：`codex-long-task-optimizer`）是一个用于将长任务文本按阶段拆解的 Python CLI 工具，目标是降低长任务一次性执行时的偏差并提高可复用性。  
  - 来源：`README.md`
  - 验证提交：`ce84c53`（最新）

## 目录与模块职责
- `src/long_task_optimizer.py`：  
  - 提供主入口 `main()`，实现参数解析和运行流程；  
  - 负责从文本中提取关键区块、按估算 token 切分、生成阶段 checkpoint 与风险/回退建议；  
  - 新增 `--version` 与 `--out`，并提供 `--no-risk` 与多格式输出能力。  
  - 来源：`src/long_task_optimizer.py`
- `examples/sample-task.txt`：当前默认任务示例与场景约束来源。  
  - 来源：`examples/sample-task.txt`
- `README.md`：公开说明、基本使用方式、输入参数说明。  
  - 来源：`README.md`
- `CONTRIBUTING.md`：变更方式与调试约定。  
  - 来源：`CONTRIBUTING.md`
- `docs/OPERATIONS.md`：维护节奏与发布策略（2 小时窗口、挤牙膏式发布）。  
  - 来源：`docs/OPERATIONS.md`
- `AGENTS.md`：本项目每次任务必须遵循的全局规则。  
  - 来源：`AGENTS.md`
- `CHANGELOG.md`：版本迭代记录。  
  - 来源：`CHANGELOG.md`
- `LICENSE`：MIT 许可。  
  - 来源：`LICENSE`
- `SECURITY.md`：安全报告流程。  
  - 来源：`SECURITY.md`
- `.github`：CI、Issue 模板、PR 模板与协作流程。  
  - 来源：`.github/workflows/ci.yml`、`.github/ISSUE_TEMPLATE`

## 技术架构与实现约束
- 以纯 Python 运行；默认文本解析与输出链路主要使用标准库模块。  
  - 依据：`src/long_task_optimizer.py:1-7`（未出现 `pip`/`requests`/`numpy` 等外部导入）
  - 依据提交：`ad9754e` 起（后续有提交更新）
- CLI 约定：默认输入文件为 `examples/sample-task.txt`，输出可为 Markdown 或 JSON。  
  - 来源：`src/long_task_optimizer.py`
- 项目元数据在 `pyproject.toml` 中声明 Python 最低版本 3.9+、开源协议、脚本入口。  
  - 来源：`pyproject.toml`
- CI 默认在 Python 3.11 下执行 smoke check 与 `pytest`。  
  - 来源：`.github/workflows/ci.yml`

## 固定业务约束（长期有效）
- 输入为文本任务描述，按“目标/范围/交付/约束/验收”字段提取关键内容（字段缺省时仍可运行）。  
  - 来源：`src/long_task_optimizer.py`
- 输出优先强调“阶段、验收、回退点、风险”。
  - 来源：`src/long_task_optimizer.py`
- 生成的执行计划强调可复用性和可回退性。  
  - 来源：`README.md`、`src/long_task_optimizer.py`

## 稳定性说明
- 本文件中的内容默认复用；若以下来源变化需同步修订：
  - `src/long_task_optimizer.py`
  - 关键输入输出约定、业务约束、目录边界
  - `AGENTS.md` 与 `docs/OPERATIONS.md`

## 关键设计决策
- 任务切分以词数近似作为 token 估算，默认上限 120。  
  - 来源：`src/long_task_optimizer.py`
- 风险清单默认开启，`--no-risk` 可关闭。  
  - 来源：`src/long_task_optimizer.py`
- 复杂度评分为文本长度和关键风险词权重的加权值，封顶为 100。  
  - 来源：`src/long_task_optimizer.py`

## 依赖与配置（当前状态）
- `pyproject.toml` 已配置构建、版本、脚本入口与项目信息。  
  - 来源：`pyproject.toml`  
  - 验证提交：`ce84c53`

## 核心约束与边界（待验证项）
- Python 运行版本下限在 `pyproject.toml` 声明为 `>=3.9`，CI 使用 Python 3.11。  
  - 来源：`pyproject.toml`、`.github/workflows/ci.yml`
- 测试与自动化检查以 `pytest` 与 CLI Smoke Check 为主。  
  - 来源：`pyproject.toml`、`.github/workflows/ci.yml`、`tests/test_long_task_optimizer.py`
