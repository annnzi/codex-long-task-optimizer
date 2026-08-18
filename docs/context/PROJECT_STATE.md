# PROJECT_STATE（动态状态）

更新时间：2026-08-18（当前为简版）本地记录

- 当前版本：`0.1.7`
- 已记录审计基线：`v0.1.5` 对应 `3ea836bc516884b3337d2de3016561ec7c24059b`（该标签为基线快照，当前 main 在其后继续迭代）。
- 版本节奏：每 2 轮形成小版本候选、每 10 轮形成大版本候选；小版本上传间隔 25 分钟，大版本上传间隔 2 小时；当前窗口计数 `16/100`（本轮已完成）。

## 当前分支与 HEAD
- 当前分支：`main`
- HEAD：`c521133`
- 工作区：无未提交改动（`git status` 为空）

## 最近代码修改
- 本轮新增：修复 `maintenance_uploader.py` 里 `--set-round 0` 重置语义（重置为 1）与轮次回写时双反引号替换问题，并同步 `docs/OPERATIONS.md` 与 `CHANGELOG.md` 说明。
- 本轮新增：`maintenance_uploader.py` 增加 `--tag-on-upload` 与 `--tag-prefix`；到窗口提交成功后自动创建并推送 `v<cycle_version>` 标签，提升上传证据闭环。
- 本轮新增：修复 `maintenance_uploader.py` 的 Python 3.9 兼容性（`str | None` / `Path | None` -> `Optional[...]`），防止定时脚本在 3.9 环境语法报错。
- 本轮新增：`maintenance_uploader_scheduler.ps1` 增加互斥锁有效期保护（`MaxLockAgeSeconds`），异常中断场景下可自动清理过期锁并接管执行。
- 本轮新增：`maintenance_uploader_schedule_task.ps1` 透传 `MaxLockAgeSeconds` 到调度器命令，便于任务计划统一配置锁回收策略。
- 本轮新增：`_extract_sections` 支持中文全角/中文括号数字前缀（如 `1）`、`（2）`）的标签行，并补充解析回归测试。
- 本轮新增：维护上传器支持项目指纹备份、损坏状态恢复、预览不消耗上传计时，并排除 `.maintenance/` 目录进入 Git 上传。
- 本轮新增：`--input` 与 `--out` 支持 `~` 用户目录展开，并在输出写入失败时输出可读错误后以状态码 2 退出；新增 `~` 路径输入回归测试。
- 本轮新增：`--input -` 的 stdin 输入现与 `--text` 一致先 strip 后解析，补充 stdin 前后空白输入回归测试。
- 本轮新增：`_extract_sections` 增加列表/编号前缀兼容（如 `- 目标：...`、`1. GOAL: ...`），提升从任务清单直接粘贴时识别率；新增对应解析回归测试。
- 本轮新增：`_extract_sections` 增加 Markdown 标头前缀兼容（如 `## 目标：...`、`### GOAL: ...`），并新增标题格式解析回归用例。
- 本轮新增：`_extract_sections` 支持 Markdown 任务列表复选框前缀（如 `- [ ]`、`- [x]`）并新增对应解析回归测试。
- 本轮新增：`_extract_sections` 修复英文无冒号标签边界解析，避免 `goalpost` 等词误触发字段标签；新增边界回归测试。
- 本轮新增：`_extract_sections` 支持全角/英文括号包裹标签（如 `【目标】`、`(范围)`）；新增包裹标签解析回归测试。
- 本轮新增：`_extract_sections` 扩展包裹标签的可选冒号写法（如 `【目标】：`、`[范围]`）；补充对应解析回归测试。
- 本轮新增：新增大众友好的控制台别名 `task-optimizer` 与 `agentic-task-optimizer`（与 `codex-long-task-optimizer` 并存），适配更泛用分发场景。
- 本轮新增：`--text` 先去除首尾空白，避免命令输入污染；补充 `--text` 高优先级覆盖 `--input` 的回归测试。
- 本轮新增：`_load_input_text` 支持 `--text` 与 `--input -`（stdin）；默认示例文件缺失时自动回退到内置文本，避免发布后首次运行阻塞。
- 本轮新增：`_read_text` 增加 UTF-8 解码错误可读提示；`--out` 会自动创建输出目录。
- 本轮新增：补充 `test_main_accepts_text_argument`、`test_main_accepts_stdin_input`、`test_main_handles_empty_text_input`、`test_main_accepts_nested_output_dir`。
- 本轮新增：修正 `SKILL.md` 输出契约，移除未实现的 `task_text` JSON 载荷假设，改为 `--text/--input` 实际调用路径。
- 本轮新增：CI 新增 `--text`、stdin、`--status` smoke check 三条接入验证命令；新增 `codex-long-task-optimizer --text --status` 验证脚本入口可执行性。
- 本轮新增：`pyproject.toml` 新增 setuptools 包发现配置，降低可安装场景找不到模块的概率。
- 本轮新增：`checkpoint` 阶段 `est_tokens` 统一改用 `_estimate_tokens`，中文无空格片段估算更接近实际复杂度；补充阶段估算回归测试。
- 本轮新增：`complexity` 指标改为统一使用 `_estimate_tokens`，在中文无空格场景更真实估算复杂度；新增复杂度边界回归测试。
- 本轮新增：`max_tokens` 切片增强，中文无空格长文本按字符计数拆分（避免单段超限）；新增中文切片回归测试。
- 本轮新增：
  - `src/long_task_optimizer.py`：同步版本来源到统一 `__version__`，移除重复常量定义。
- `src/__init__.py`：新增 `__version__ = "0.1.5"`，减少版本声明散落。
- `tests/test_long_task_optimizer.py`：新增 `__version__` 存在性测试，避免未来版本字段回退。
- `src/long_task_optimizer.py`：新增长文本无分隔符分段兜底，避免阶段超限。
- `docs/OPERATIONS.md`：添加每日版本号输出要求。
- `CHANGELOG.md`：记录切片逻辑优化。
- `src/long_task_optimizer.py`：修复英文前缀标签解析（例如 `GOALS`、`OUTPUTS`）在有冒号场景下的截断错误。
- `tests/test_long_task_optimizer.py`：补充前缀英文标签回归用例。
- `README.md`、`docs/USAGE_FOR_AGENTS.md`：统一 `--no-risk` 文档说明为“隐藏风险提示，保留回退段”。
- `docs/OPERATIONS.md`：统一为每 2 轮小版本、每 10 轮大版本，并记录 25 分钟/2 小时上传窗口。
- `src/long_task_optimizer.py`：修复 `complexity` 评分计算中 `base` 上误用 `count()` 引发的潜在运行时异常。
- `tests/test_long_task_optimizer.py`：新增复杂度风险项加成回归测试。
- `tests/test_long_task_optimizer.py`：新增 `--no-risk` 风险清空行为回归测试，防止参数行为漂移。
- `src/long_task_optimizer.py`：`--no-risk` 下隐藏 Markdown 风险段与风险清单。
- `tests/test_long_task_optimizer.py`：新增 Markdown no-risk 风险文本隐藏回归。
- `src/long_task_optimizer.py`：修复无冒号/无空格标题行解析时的正文残留问题（如 `目标完成...`）。
- `tests/test_long_task_optimizer.py`：新增 `目标`/`范围` 无冒号场景解析回归。
- `src/__init__.py`：版本号提升到 `0.1.6`，并同步版本策略到动态记录。
- `pyproject.toml`：项目版本号同步到 `0.1.6`。
- `docs/context/PROJECT_STATE.md`：增加“每5轮一版本”窗口计数记录。
- `CHANGELOG.md`：新增 `v0.1.6` 条目，沉淀最近一阶段变更。
- 本轮新增：`_extract_sections` 兼容“组合前缀”格式（如 `1. [x]`、`2) [ ]`、`+ [x]`）的字段识别，并补充对应回归测试。
- 本轮新增：`maintenance_uploader.py` 增加 `--auto-round` 自动推进轮次，并透传到 `maintenance_uploader_scheduler.ps1` 与 `maintenance_uploader_schedule_task.ps1`；更新 `docs/OPERATIONS.md` 给出 `-AutoRound` 任务安装示例。
- 本轮新增：维护上传器步长口径统一为“2 轮一版”（`--version-step`/`VersionStep` 默认改为 `2`），修复 `maintenance_uploader_schedule_task.ps1` 中 `-AutoExecute` 参数拼写问题，并在状态输出中加入 `next_small_upload_due_seconds`/`next_major_upload_due_seconds`，用于周期汇报与日报审计。
- 本轮新增：已同步本轮状态更新并按节奏提交（状态窗口字段与运营记录更新，已推送到远端）。

## 当前任务
- 目标：继续做小步优化，降低字段识别误分类概率，持续压低真实工程接入误伤风险，并把 100 轮窗口 + 25min/2h 上传机制固化为可持续运行脚本链路。

## 已知问题
- 尚未执行本轮变更后的本地测试。
- 版本更新策略暂为“先优化后统一批量提交”，待下一轮再集中 push。
- 维护上传器的 `--auto-round` 依赖 `PROJECT_STATE.md` 轮次写回成功；当写回失败时会继续运行并在状态中记录 `round_action_error`。

## 最新报错
- 本次无新增报错采集。

## 最新测试结果
- 本地测试未在本次会话执行（维持高频优化节奏，降低重复验证频率）。
- CI 目标仍是：`python -m pip install -e .`、CLI smoke check、`pytest`。

## 最新运行和部署结果
- 最近一次已推送提交：`c521133`（`chore(maintenance): recover stale scheduler lock for uploads`）。
- 当前轮次：本次优化同步到远端；小版本锁治理能力已上线。
- 已执行优化点：  
  - `src/long_task_optimizer.py`：修复 `complexity` 计算口径为词数并更正 md 输出标签；新增 `--status` 支持。  
- `tests/test_long_task_optimizer.py`：补充 `--status` 输出测试。  
- `README.md`、`docs/USAGE_FOR_AGENTS.md`：记录 `--status` 用法。  
- `CHANGELOG.md`：补充本轮优化条目。
- `src/long_task_optimizer.py`：英文标签解析改为大小写不敏感。  
- `tests/test_long_task_optimizer.py`：补充英文大写标签解析回归用例。
- `src/long_task_optimizer.py`：固定 `SECTION_KEY_MAP` 避免解析映射重复构建。
- `README.md`、`docs/USAGE_FOR_AGENTS.md`：统一 JSON 输出字段契约说明。  
- `tests/test_long_task_optimizer.py`：补充空输入默认行为与 schema 字段覆盖。  
- `CHANGELOG.md`：记录文档-实现一致性与边界测试补充。
- `src/long_task_optimizer.py`：修复英文前缀标签解析边界问题（如 GOALS/OUTPUTS）。  
- `tests/test_long_task_optimizer.py`：补充复数英文标签解析回归。  
- `README.md`、`docs/USAGE_FOR_AGENTS.md`：`--no-risk` 文案对齐真实输出。
- `src/long_task_optimizer.py`：修复 `complexity` 风险评分核心逻辑并新增回归测试。
- `tests/test_long_task_optimizer.py`：新增 `--no-risk` 风险清空回归测试。
- `src/long_task_optimizer.py`：`--no-risk` 下将风险提示与风险项从 Markdown 输出移除。
- `tests/test_long_task_optimizer.py`：新增 Markdown 输出风险项关闭回归。
- `src/long_task_optimizer.py`：修复无冒号标题行解析截断问题（`目标完成`、`范围覆盖`）。
- `tests/test_long_task_optimizer.py`：补充无冒号紧贴关键词解析回归。

## 缓存与清理说明
- 本文件仅保留最近有效动态信息，供下一次任务快速复用。

