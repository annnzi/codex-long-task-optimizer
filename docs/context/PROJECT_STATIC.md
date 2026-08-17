# PROJECT_STATIC（静态上下文）

最后验证：2026-08-17

## 项目范围与目标
- `codex-long-task-optimizer` 是一个用于将长任务文本按阶段拆解的 Python CLI 工具，目标是降低长任务一次性执行时的偏差并提高可复用性。  
  - 来源：`README.md`
  - 验证提交：`无提交（仓库当前未建立 git 提交，HEAD 未创建）`

## 目录与模块职责
- `src/long_task_optimizer.py`：  
  - 提供主入口 `main()`，实现参数解析和运行流程；  
  - 负责从文本中提取关键区块、按估算 token 切分、生成阶段 checkpoint 与风险/回退建议。  
  - 来源：`src/long_task_optimizer.py`
- `examples/sample-task.txt`：当前默认任务示例与场景约束来源。  
  - 来源：`examples/sample-task.txt`
- `README.md`：公开说明、基本使用方式、输入参数说明。  
  - 来源：`README.md`
- `CONTRIBUTING.md`：变更方式与调试约定。  
  - 来源：`CONTRIBUTING.md`
- `AGENTS.md`：本项目每次任务必须遵循的全局规则。  
  - 来源：`AGENTS.md`
- `LICENSE`：MIT 许可。  
  - 来源：`LICENSE`

## 技术架构与实现约束
- 以纯 Python 运行，无额外第三方依赖导入；默认文本解析与输出链路全部使用标准库模块。  
  - 依据：`src/long_task_optimizer.py:1-7`（未出现 `pip`/`requests`/`numpy` 等外部导入）
  - 验证提交：`无提交`
- CLI 约定：默认输入文件为 `examples/sample-task.txt`，输出可为 Markdown 或 JSON。  
  - 来源：`src/long_task_optimizer.py`

## 固定业务约束（长期有效）
- 输入为文本任务描述，按“目标/范围/交付/约束/验收”字段提取关键内容（字段缺省时仍可运行）。  
  - 来源：`src/long_task_optimizer.py`
- 输出优先强调“阶段、验收、回退点、风险”。
  - 来源：`src/long_task_optimizer.py`
- 生成的执行计划强调可复用性和可回退性。  
  - 来源：`README.md`、`src/long_task_optimizer.py`

## 关键设计决策
- 任务切分以词数近似作为 token 估算，默认上限 120。  
  - 来源：`src/long_task_optimizer.py`
- 风险清单默认开启，`--no-risk` 可关闭。  
  - 来源：`src/long_task_optimizer.py`
- 复杂度评分为文本长度和关键风险词权重的加权值，封顶为 100。  
  - 来源：`src/long_task_optimizer.py`

## 依赖与配置（当前状态）
- 在目标目录未发现集中式依赖清单/构建配置/测试配置文件（如 `requirements.txt`、`pyproject.toml`、`setup.py`、`setup.cfg`、`tox.ini`、`.github/workflows`）。  
  - 来源：本次仓库读取范围扫描（`codex-long-task-optimizer` 及子目录，3 层深度）  
  - 验证提交：`无提交`

## 核心约束与边界（待验证项）
- `Python` 版本下限未在文件中显式声明。  
  - 来源：`README.md`、`src/long_task_optimizer.py`（未显式声明）  
  - 备注：此项为待验证信息，需结合环境实际运行时补充。
- 测试框架与CI规范未定义。  
  - 来源：`src/long_task_optimizer.py`、仓库根目录文件扫描  
  - 备注：如后续新增 `pytest`/`ruff`/CI workflow，按动态信息更新。
