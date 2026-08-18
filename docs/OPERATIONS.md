# 运营节奏（长期维护）

目标：让仓库以真实、可追踪的小步迭代持续维护。

原则
- 每次只做小改动：优先一次改 1 个点位（代码或文档中的单一能力）。
- 每 2 轮形成一个小版本候选，每 10 轮形成一个大版本候选。
- 小版本上传间隔为 25 分钟，大版本上传间隔为 2 小时；只有对应轮次且存在项目变更时才上传。
- 版本号按“2 轮一版”策略递增（默认 `--version-step 2`），用于对外汇报当前阶段。
- 默认先预览上传建议，明确执行 `--execute` 后才会运行 `git add/commit/push`。
- `.maintenance/` 只保存本地备份和上传器状态，不进入公开仓库。

节奏模板
1. **本地优化**（按轮次推进）
   - 修改单个文件（或一个紧密相关的文件组）
   - 保持提交信息简短清晰
2. **本地记录**
   - 更新 `docs/context/PROJECT_STATE.md` 的“最近代码修改/动态”字段
- 仅当完成该时段目标后再提交一次
3. **上传窗口到位**
   - 小版本窗口：25 分钟检查一次
   - 大版本窗口：2 小时检查一次
   - 在仓库里只保留该窗口的一次小步提交
   - 窗口计数控制建议：从 1 开始累计到 100。

自动化入口

```powershell
python scripts/maintenance_uploader.py --repo .
python scripts/maintenance_uploader.py --repo . --loop --interval-seconds 60
python scripts/maintenance_uploader.py --repo . --execute
python scripts/maintenance_uploader.py --repo . --advance-round   # 当前窗口计数 +1
python scripts/maintenance_uploader.py --repo . --set-round 16    # 手工设置窗口计数
python scripts/maintenance_uploader.py --repo . --set-round 16 --max-round 100
python scripts/maintenance_uploader.py --repo . --auto-round         # 检测到文件签名变化时自动 +1
python scripts/maintenance_uploader.py --repo . --auto-round --auto-execute # 到窗口并检测到变更时自动提交
python scripts/maintenance_uploader.py --repo . --auto-round --auto-execute --version-step 2
$loopLog = ".\\.maintenance\\logs\\maintenance_uploader.log"
.\scripts\maintenance_uploader_scheduler.ps1 -LogPath $loopLog
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode status
.\scripts\maintenance_uploader_scheduler.ps1 -LogPath ".\\.maintenance\\logs\\maintenance_uploader.log"
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode install -AutoRound -AutoExecute
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode install -AutoRound -AutoExecute -LogPath ".\\.maintenance\\logs\\maintenance_uploader.log"
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode install -AutoRound -Execute
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode install -AutoRound -AutoExecute -Execute
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode install -PythonCmd "python"
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode uninstall
Get-Content .\\.maintenance\\logs\\maintenance_uploader.log -Tail 80
Select-String -Path .\\.maintenance\\logs\\maintenance_uploader.log -Pattern '"uploaded":' | Select-Object -Last 5
```

脚本每次检测项目文件指纹变化；发生变化时先创建本地 ZIP 备份，再按轮次和时间窗口给出上传结果。循环模式不会因为上传器自己的状态文件而重复备份或触发上传。

最小可见行为（建议每周）
- 每周至少 3 次 PR/Commit
- 每周至少 1 条 Issues/讨论回应（哪怕是维护状态说明）
- 至少发布 1 次版本或更新日志注释（即使是小版本）

验收口径
- 公开仓库有持续活动（commit 时间戳可见）
- 变更文件不堆砌：每次只推一类小改动
- 说明文档与运行状态随迭代同步更新
- 每日对外输出需附带当前版本号（用于长期追踪与申请证明）。

### 推荐默认定时安装（每分钟单次检查）
.\scripts\maintenance_uploader_scheduler.ps1 -LogPath ".\\.maintenance\\logs\\maintenance_uploader.log"
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode install -TaskIntervalMinutes 1 -AutoRound -AutoExecute -VersionStep 2
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode install -TaskIntervalMinutes 1 -AutoRound -AutoExecute -VersionStep 2 -LogPath ".\\.maintenance\\logs\\maintenance_uploader.log"
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode status
.\scripts\maintenance_uploader_schedule_task.ps1 -Mode uninstall
Select-String -Path .\\.maintenance\\logs\\maintenance_uploader.log -Pattern '"mode":' | Select-Object -Last 5
.\scripts\maintenance_uploader_scheduler.ps1 -Loop -LogPath $loopLog
说明：默认不加 `-Loop` 时，任务计划会按 "每分钟执行一次短流程"，只负责一次检测；若需手工驻留运行，可加 `-Loop` 让该计划命令持续运行。
.\scripts\maintenance_uploader_scheduler.ps1 -LogPath $loopLog -MaxLogBytes 5242880
说明：日志超出 5MB 时会自动轮转为 `maintenance_uploader.log.YYYYMMDD_HHMMSS`。
说明：脚本默认自动加互斥锁，防止计划任务在一分钟内重叠执行；如果你需要自定义锁文件，可加 `-LockPath`。
.\scripts\maintenance_uploader_health.ps1 -LogPath ".\\.maintenance\\logs\\maintenance_uploader.log" -TailLines 200
说明：用于快速统计最近执行状态，判断是否有长时间 `idle`、解析异常或未触发上传情况。
.\scripts\maintenance_uploader_health.ps1 -LogPath ".\\.maintenance\\logs\\maintenance_uploader.log" -TailLines 400 -AlertNoUploadWindow 8 -AsReport
说明：返回一行 CSV，可直接写入日报表。
说明：如果 `maintenance_uploader.py` 解析 PROJECT_STATE 失败，会在 `状态：{...}` 里出现 `mode=error`，在日报 `risk_flag` 中通常显示 `warn`。
说明：状态行增加 `next_small_upload_due_seconds` 与 `next_major_upload_due_seconds`，可直接用于“下一次上传窗口”汇报。
python .\scripts\maintenance_uploader.py --repo . --advance-round         # 每次优化完成后手工调用，推进轮次
python .\scripts\maintenance_uploader.py --repo . --set-round 0 --max-round 100 # 复位计数（重置为 1）
python .\scripts\maintenance_uploader.py --repo .
