# PROJECT_STATE（动态状态）

更新时间：2026-08-21（当前为简版）本地记录

- 当前版本：`0.3.2`
- 已记录审计基线：`v0.1.5` 对应 `3ea836bc516884b3337d2de3016561ec7c24059b`（该标签为基线快照，当前 main 在其后继续迭代）。
- 版本节奏：每 2 轮形成小版本候选、每 10 轮形成大版本候选；小版本上传间隔 25 分钟，大版本上传间隔 2 小时；当前窗口计数 `34/100`（本轮已完成）。
- 本轮补充：备份排除项收口（与签名采样一致），减少 `.pytest_cache/.mypy_cache/.ruff_cache` 等噪声内容进入 ZIP，避免每次更新备份体积失控。
- 本轮补充：新增 `scripts/maintenance_uploader_timer.ps1`，用于一条命令执行“初始化定时器/状态查看/运行一次/健康报告/停止”。

- 本轮补充：`maintenance_uploader_cadence.ps1`、`maintenance_uploader_ops.ps1`、`maintenance_uploader_schedule_task.ps1` 已统一 UTF-8 ASCII 无障碍模式，消除中文编码导致的 help/status 直接执行解析异常。
- 本轮补充：`maintenance_uploader_cadence.ps1` 新增子进程退出码透传，status/health 无日志时会返回非 0 提示，便于自动化告警。
- 本轮补充：`maintenance_uploader_schedule_task.ps1` 优化任务不存在分支处理，`status` 不再抛出 schtasks 异常输出。

## 当前分支与 HEAD
- 当前分支：`codex/maintenance-v0.3.2`
- HEAD：`4a3c96f`（已提交并推送到版本分支）
- 工作区：无未提交改动

## 最近代码修改
- 本轮新增：`maintenance_uploader.py` 新增 `100` 轮周期里程碑记录能力，补充 `last_cycle_boundary_round`、`last_cycle_boundary_ts`，在 `round_cycle_completed` 触发时输出 `cycle_boundary_*` 字段到状态 JSON。
- 本轮新增：`maintenance_uploader_health.ps1` 采集并显示 `round_cycle_completed` 相关里程碑字段（含 `cycle_boundary_round`、`cycle_boundary_ts`），便于在健康摘要快速确认“本窗口是否完成 100 轮闭环”。
- 本轮新增：新增 `scripts/maintenance_uploader_ops.ps1`，提供一键运维入口（`start/stop/status/run/run-loop/health`），用于减少命令拼接成本。
- 本轮新增：`maintenance_uploader_health.ps1` 重构状态解析，支持更多前缀/宽松格式，新增无法解析样例回显，降低“无 structured status found”误报。
- 本轮新增：`maintenance_uploader_health.ps1` 新增 `-AuditPath`，`maintenance_uploader_ops.ps1` `health` 模式默认写入 `.maintenance\\logs\\maintenance_uploader_audit.csv`，用于长周期审计留痕。
- 本轮新增：`maintenance_uploader.py` 新增 `--adaptive-loop` 与 `--audit-csv`；`maintenance_uploader_scheduler.ps1` 与 `maintenance_uploader_schedule_task.ps1` 已透传该参数，`ops` 一键入口支持自适应循环和持续状态审计。
- 本轮新增：`maintenance_uploader_ops.ps1` 与 `maintenance_uploader_scheduler.ps1` 增加路径归一化：`LogPath`、`AuditCsv`、`AuditPath` 若为相对路径会自动按仓库根目录展开为绝对路径，避免任务计划环境导致日志与审计 CSV 落位混乱。
- 本轮新增：`maintenance_uploader.py` 同时输出 `status:` 与 `状态：` 两类 JSON 状态行，兼容更多日志采集器与解析脚本。
- 本轮新增：`scripts/maintenance_uploader_schedule_task.ps1` 和 `scripts/maintenance_uploader_scheduler.ps1` 支持 Python 命令自动降级探测（`python` -> `python3` -> `py`），避免单一 `python` 不可用时任务启动失败。
- 本轮新增：`maintenance_uploader_schedule_task.ps1` 新增 `-ReplaceIfExists` 与 `-MaxRound`，支持重复部署任务计划而不中断历史；已透传 `--max-round` 到 `maintenance_uploader_scheduler.ps1`，使 100 轮窗口策略在任务计划链路内显式生效。
- 本轮新增：`scripts/maintenance_uploader_health.ps1` 修正“最近窗口”显示逻辑，新增 `nearest_small_due` / `nearest_major_due`，并输出最近/最远窗口倒计时（便于日报判断何时到窗口）。
- 本轮新增：新增 `scripts/maintenance_uploader_cadence.ps1`，提供 `init/status/run/run-loop/health/stop/help` 一站式入口，支持“观察模式/自动提交”一体化运营（含 25 分钟与 2 小时窗口口径）。
- 本轮新增：修复 `maintenance_uploader_cadence.ps1` 参数数组尾随逗号导致的 ParserError（`-Mode help` 与直接调用异常），现已恢复正常。
- 本轮新增：`maintenance_uploader.py` 备份命名加上窗口轮次与版本标识（如 `_r16-v0.1.7`），便于“每次更新一份备份”可追溯到版本窗口。
- 本轮新增：`maintenance_uploader.py` 的 `auto-round` 改为仅在签名变更时推进，避免无文件变更导致的误触发。
- 本轮新增：修复 `maintenance_uploader.py` 里 `--set-round 0` 重置语义（重置为 1）与轮次回写时双反引号替换问题，并同步 `docs/OPERATIONS.md` 与 `CHANGELOG.md` 说明。
- 本轮新增：`maintenance_uploader.py` 增加 `--tag-on-upload` 与 `--tag-prefix`；到窗口提交成功后自动创建并推送 `v<cycle_version>` 标签，提升上传证据闭环。
- 本轮新增：修复 `maintenance_uploader.py` 的 Python 3.9 兼容性（`str | None` / `Path | None` -> `Optional[...]`），防止定时脚本在 3.9 环境语法报错。
- 本轮新增：修正 `maintenance_uploader.py` 的 `cycle_version` 计数方式：按累计周期递增版本，避免 `round_count` 回绕后重复 `cycle_version` 与标签名。
- 本轮新增：修复 `_derive_cycle_version`，改为按累计总轮次（`cycles_completed * max_round + round_count`）进行整数递增，避免 `max_round` 与 `version_step` 不整除时跨周期漏增版本。
- 本轮新增：`maintenance_uploader.py` 将周期完成提示文案改为动态上限（`max_round`），避免将 100 写死在状态提示中。
- 本轮新增：`maintenance_uploader_scheduler.ps1` 增加互斥锁有效期保护（`MaxLockAgeSeconds`），异常中断场景下可自动清理过期锁并接管执行。
- 本轮新增：`maintenance_uploader_schedule_task.ps1` 透传 `MaxLockAgeSeconds` 到调度器命令，便于任务计划统一配置锁回收策略。
- 本轮新增：`maintenance_uploader_scheduler.ps1` 增强死锁识别逻辑：通过进程命令行确认锁占用进程来源，避免 PID 重用导致误判；并在正常执行完成后清理锁文件。
- 本轮新增：`scripts/maintenance_uploader_health.ps1` 提升日志结构化解析稳定性（支持更多 `状态` 前缀）并补充版本/窗口到期字段，提升健康报表可读性与准确性。
- 本轮新增：`scripts/maintenance_uploader_health.ps1` 进一步采集 `project_version`、`round_action`、`state_source`、`cycle_tag` 与 `version_step` 字段，支持一行输出快速判断是否真正推进轮次并生成可复用的日报字段。
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
- 本轮新增：`maintenance_uploader.py` 新增 100 轮周期追踪指标，记录 `cycles_completed`（累计完成周期数）与 `round_cycle_completed`（当前轮次是否跨越 100 重置）到状态行。
- 本轮新增：`maintenance_uploader_health.ps1` 增强 `-AsReport` 输出，新增 `cycles_completed` 与 `round_cycle_completed` 字段，便于快速核对“每 100 轮”节奏。

## 当前任务
- 目标：继续做小步优化，降低字段识别误分类概率，持续压低真实工程接入误伤风险，并把 100 轮窗口 + 25min/2h 上传机制固化为可持续运行脚本链路。

## 已知问题
- 维护上传器的 `--auto-round` 依赖 `PROJECT_STATE.md` 轮次写回成功；当写回失败时会继续运行并在状态中记录 `round_action_error`。

## 最新报错
- 本轮未发现新的脚本语法回归。
- 历史中文字符串编码导致的 `cadence`/`ops`/`schedule` 解析问题已修复。
- 现象验证：`maintenance_uploader_cadence.ps1 -Mode status` 在无日志场景返回 `1`（预期告警），`health` 在无日志场景返回 `2`（预期告警）。
- 新增脚本 `maintenance_uploader_timer.ps1` `-Mode help` 正常输出；`-Mode status` 在无日志时返回 `1`，符合当前检查策略（任务未就绪提示）。

## 最新测试结果
- 已完成 PowerShell 脚本语法自检：`maintenance_uploader.py`、`maintenance_uploader_health.ps1`、`maintenance_uploader_scheduler.ps1`、`maintenance_uploader_schedule_task.ps1`、`maintenance_uploader_ops.ps1`、`maintenance_uploader_cadence.ps1` 均通过 `PSParser` 解析校验。
- 已执行脚本冒烟：`powershell -ExecutionPolicy Bypass -File scripts/maintenance_uploader_health.ps1 -LogPath .tmp_health_test.log -TailLines 20 -AsReport`（成功输出 CSV 报表）
- 已执行脚本冒烟：`powershell -ExecutionPolicy Bypass -File .\\scripts\\maintenance_uploader_cadence.ps1 -Mode help`（可输出完整帮助信息，`help` 分支可执行）。
- 已执行脚本冒烟：`powershell -ExecutionPolicy Bypass -File .\\scripts\\maintenance_uploader_cadence.ps1 -Mode status`（未安装任务时安全提示：任务不存在、无可读日志）。
- 已执行脚本冒烟：`powershell -ExecutionPolicy Bypass -File .\\scripts\\maintenance_uploader_ops.ps1 -Mode status`（任务不存在时返回提示，退出码 1）。
- 已执行脚本冒烟：`powershell -ExecutionPolicy Bypass -File .\\scripts\\maintenance_uploader_cadence.ps1 -Mode health`（无日志文件时返回提示，退出码 2）。
- 已执行脚本冒烟：`powershell -ExecutionPolicy Bypass -File .\\scripts\\maintenance_uploader_schedule_task.ps1 -Mode status`（任务不存在分支静默提示，退出码 0）。
- 已执行脚本冒烟：`powershell -ExecutionPolicy Bypass -File .\\scripts\\maintenance_uploader_timer.ps1 -Mode help`（输出帮助，退出码 0）。
- 已执行脚本冒烟：`powershell -ExecutionPolicy Bypass -File .\\scripts\\maintenance_uploader_timer.ps1 -Mode status -TaskName __codex_timer_smoke__`（返回提示，退出码 1）。
- 已补充命令说明：`python scripts/maintenance_uploader.py --repo . --auto-round --max-round 100`（按签名变化自动推进、并生成 `_r*-v*` 命名备份）。
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
- 本轮计数：第 34/100 轮；本地版本线已升为 `0.3.2`，本轮未提交、未推送。
- 本轮升级：Markdown 与 JSON 输出统一携带应用、版本和协议元数据。
- 本轮优化：备份 manifest 记录触发备份时的项目签名，增强恢复和审计能力。
- 本轮修复：核心 CLI 使用明确 UTC 时间戳，保持 `Z` 格式兼容。
- 本轮优化：PowerShell 定时入口支持显式 `AllowSensitive`，默认仍阻止敏感文件上传。
- 本轮升级：JSON 计划结果新增 schema、应用和版本元数据，进入 `0.3.0` 大版本节点。
- 本轮优化：自动上传前增加高风险文件保护，默认阻止敏感文件进入公开仓库。
- 本轮修复：标签推送失败会持久化为 `pending_tag`，下一次执行可恢复推送。
- 本轮修复：轮次回写改用原子文本替换，保护 `PROJECT_STATE.md` 不被中断写坏。
- 本轮修复：上传器识别并重试工作区干净但分支领先远端的本地提交。
- 本轮修复：scheduler 锁采用独占创建并强制刷盘，降低并发运行和异常中断后的锁误判。
- 本轮修复：scheduler 显式传播 Python 非零退出码，避免定时任务吞掉维护失败。
- 本轮优化：每个 ZIP 备份内新增 `backup-manifest.json`，记录备份来源和文件数量。
- 本轮修复：状态与备份采用临时文件原子替换，避免中断后留下可被误读的半文件。
- 本轮优化：定时 PowerShell 封装层统一传递 `MaxBackups`，计划任务安装器也具备本地 Python 回退。
- 本轮修复：定时 scheduler 优先查找仓库 `.venv` / `venv` Python，避免系统命令缺失导致维护链路无法启动。
- 本轮修复：维护上传器在 Windows 下强制 UTF-8 输出，减少定时日志中的中文乱码。
- 本轮修复：维护上传器不再把轮次增量重复叠加到项目版本；备份与标签统一使用当前项目版本 `0.1.8`。
- 本轮补充：维护上传器新增 `--max-backups`，默认只保留最近 10 个备份，避免备份目录无限增长。
- 本轮补充：timer 的 `bootstrap` 默认幂等更新计划任务，重复执行不会因任务已存在而失败。
- 本文件仅保留最近有效动态信息，供下一次任务快速复用。

