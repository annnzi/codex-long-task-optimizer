#!/usr/bin/env python3
"""Maintenance helper for cadence-based backup and optional upload.

Usage examples:
- 一次性运行（默认仅备份，不主动提交）：
  python scripts/maintenance_uploader.py --repo .
- 每 60 秒循环检测并按窗口输出建议（不主动提交）：
  python scripts/maintenance_uploader.py --repo . --loop --interval-seconds 60
- 手工推进窗口计数（用于你自己的 2/10 轮进度跟踪）：
  python scripts/maintenance_uploader.py --repo . --advance-round
- 手工设置窗口计数（例如从 15 设置到 16）：
  python scripts/maintenance_uploader.py --repo . --set-round 16
- 检测到项目变更自动推进轮次（适合常驻循环）：
  python scripts/maintenance_uploader.py --repo . --auto-round
- 进入推送模式（预览确认后）：
  python scripts/maintenance_uploader.py --repo . --execute
- 进入自动执行上传（到达窗口时自动提交）：
  python scripts/maintenance_uploader.py --repo . --auto-execute
- 进入自动执行上传（按 2 轮一版）：
  python scripts/maintenance_uploader.py --repo . --auto-round --auto-execute --version-step 2
- 进入自动执行上传并自动打标签（按 2 轮一版）：
  python scripts/maintenance_uploader.py --repo . --auto-round --auto-execute --tag-on-upload --version-step 2
""" 

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import time
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROUND_COUNTER_LABEL_PATTERN = re.compile(
    r"((?:当前窗口计数|窗口计数)\s*[:：]?\s*)`?\s*\d+\s*/\s*\d+\s*`?"
)
ROUND_COUNT_VALUE_PATTERN = re.compile(
    r"(?:当前窗口计数|窗口计数)\s*[:：]?\s*[`\"“”']?\s*(\d+)\s*/\s*(\d+)\s*[`\"“”']?"
)


def _normalise_int(value: object, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _window_due_seconds(state: dict, key: str, interval_seconds: int, *, now_ts: float) -> int:
    ts = float(state.get(key, {}).get("ts", 0))
    due = int(max(0.0, interval_seconds - (now_ts - ts)))
    return due


def _parse_round_count(state_path: Path) -> tuple[int, int]:
    text = state_path.read_text(encoding="utf-8")
    match = ROUND_COUNT_VALUE_PATTERN.search(text)
    if match is None:
        fallback = re.search(r"(?:窗口计数|round)\s*[:：]?\s*[`\"“”']?\s*(\d+)\s*/\s*(\d+)\s*[`\"“”']?", text, re.IGNORECASE)
        if fallback is None:
            raise ValueError("无法从 docs/context/PROJECT_STATE.md 解析轮次")
        match = fallback
    round_count = int(match.group(1))
    max_round = int(match.group(2))
    if max_round <= 0:
        raise ValueError("max_round 不能小于等于 0")
    if round_count < 1:
        round_count = 1
    if round_count > max_round:
        round_count = max_round
    return round_count, max_round


def _read_project_version(repo_dir: Path) -> str:
    pyproject = repo_dir / "pyproject.toml"
    if not pyproject.exists():
        return "0.0.0"
    try:
        text = pyproject.read_text(encoding="utf-8")
    except OSError:
        return "0.0.0"
    match = re.search(r"^\s*version\s*=\s*[\"']([^\"']+)[\"']", text, re.MULTILINE)
    if not match:
        return "0.0.0"
    return match.group(1).strip()


def _derive_cycle_version(
    base_version: str,
    round_count: int,
    *,
    version_step: int,
) -> str:
    version_match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", base_version.strip())
    if not version_match:
        return f"{base_version}-r{round_count}"
    major, minor, patch = [int(x) for x in version_match.groups()]
    if version_step <= 0:
        version_step = 1
    if round_count <= 0:
        return f"{major}.{minor}.{patch}"
    # 每 N 轮递增一次；例如 version_step=2 时，第 2/4/6... 轮递增一版。
    increment = round_count // version_step
    return f"{major}.{minor}.{patch + increment}"


def _state_file(path: Path) -> Path:
    return path / ".maintenance" / "upload_state.json"


def _default_uploader_state() -> dict:
    return {
        "last_backup_ts": 0,
        "last_backup_signature": "",
        "last_round_count": {"value": 0, "max": 100, "updated_at": 0, "source": "bootstrap"},
        "last_small_upload": {"ts": 0, "round": 0},
        "last_major_upload": {"ts": 0, "round": 0},
    }


def _normalise_upload_slot(value: object) -> dict:
    if not isinstance(value, dict):
        return {"ts": 0, "round": 0}
    try:
        return {"ts": float(value.get("ts", 0)), "round": int(value.get("round", 0))}
    except (TypeError, ValueError):
        return {"ts": 0, "round": 0}


def _normalise_round_slot(value: object) -> dict:
    if not isinstance(value, dict):
        return {"value": 0, "max": 100, "updated_at": 0, "source": "bootstrap"}
    return {
        "value": _normalise_int(value.get("value"), 0),
        "max": max(1, _normalise_int(value.get("max"), 100)),
        "updated_at": _normalise_int(value.get("updated_at"), 0),
        "source": str(value.get("source", "bootstrap")),
    }


def _load_uploader_state(path: Path) -> dict:
    payload_path = _state_file(path)
    state = _default_uploader_state()
    if not payload_path.exists():
        return state
    try:
        payload = json.loads(payload_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return state
    if not isinstance(payload, dict):
        return state
    try:
        state["last_backup_ts"] = float(payload.get("last_backup_ts", 0))
    except (TypeError, ValueError):
        pass
    state["last_backup_signature"] = str(payload.get("last_backup_signature", ""))
    state["last_round_count"] = _normalise_round_slot(payload.get("last_round_count"))
    state["last_small_upload"] = _normalise_upload_slot(payload.get("last_small_upload"))
    state["last_major_upload"] = _normalise_upload_slot(payload.get("last_major_upload"))
    return state


def _save_uploader_state(path: Path, state: dict) -> None:
    payload_path = _state_file(path)
    payload_path.parent.mkdir(parents=True, exist_ok=True)
    payload_path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def _classify_upload_type(round_count: int) -> str:
    if round_count > 0 and round_count % 10 == 0:
        return "major"
    if round_count > 0 and round_count % 2 == 0:
        return "small"
    return "idle"


def _create_backup(repo_dir: Path) -> Path:
    now = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    backup_dir = repo_dir / ".maintenance" / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup_file = backup_dir / f"backup-{now}.zip"

    exclude = {".git", ".maintenance", "__pycache__", ".venv", ".pytest_cache"}
    with zipfile.ZipFile(backup_file, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for item in sorted(repo_dir.rglob("*")):
            if not item.is_file():
                continue
            rel = item.relative_to(repo_dir)
            if any(part in exclude for part in rel.parts):
                continue
            if rel.suffix == ".pyc":
                continue
            zf.write(item, rel.as_posix())
    return backup_file


def _project_signature(repo_dir: Path) -> str:
    digest = hashlib.sha256()
    exclude = {".git", ".maintenance", "__pycache__", ".venv", ".pytest_cache"}
    for item in sorted(repo_dir.rglob("*")):
        if not item.is_file():
            continue
        rel = item.relative_to(repo_dir)
        if any(part in exclude for part in rel.parts) or rel.suffix == ".pyc":
            continue
        try:
            stat = item.stat()
        except FileNotFoundError:
            continue
        digest.update(rel.as_posix().encode("utf-8"))
        digest.update(f"\0{stat.st_size}\0{stat.st_mtime_ns}\n".encode("ascii"))
    return digest.hexdigest()


def _git_project_status(repo_dir: Path) -> str:
    return subprocess.check_output(
        [
            "git",
            "status",
            "--porcelain",
            "--untracked-files=all",
            "--",
            ".",
            ":(exclude).maintenance",
            ":(exclude).maintenance/**",
        ],
        cwd=repo_dir,
        text=True,
    )


def _git_has_changes(repo_dir: Path) -> bool:
    return bool(_git_project_status(repo_dir).strip())


def _run_cmd(cmd: list[str], repo_dir: Path) -> None:
    subprocess.run(cmd, cwd=repo_dir, check=True)


def _push_tags(repo_dir: Path) -> None:
    _run_cmd(["git", "push", "--tags"], repo_dir)


def _tag_round_upload(
    repo_dir: Path,
    cycle_version: str,
    *,
    tag_prefix: str = "v",
) -> str | None:
    tag_name = f"{tag_prefix}{cycle_version}"
    try:
        _run_cmd(["git", "rev-parse", "--verify", tag_name], repo_dir)
        return None
    except subprocess.CalledProcessError:
        pass
    _run_cmd(
        [
            "git",
            "tag",
            "-a",
            tag_name,
            "-m",
            f"Maintenance snapshot for cycle {cycle_version}",
        ],
        repo_dir,
    )
    _push_tags(repo_dir)
    return tag_name


def _upload_if_due(
    repo_dir: Path,
    round_count: int,
    now_ts: float,
    args: argparse.Namespace,
    cycle_version: str,
) -> tuple[bool, str, str, str]:
    state = _load_uploader_state(repo_dir)
    mode = _classify_upload_type(round_count)
    if mode == "idle":
        return False, "本轮未触发上传门槛（1/2/10轮）", mode, ""

    interval = args.major_interval_seconds if mode == "major" else args.small_interval_seconds
    key = "last_major_upload" if mode == "major" else "last_small_upload"
    elapsed = now_ts - state[key]["ts"]
    if elapsed < interval:
        mins = int(elapsed / 60)
        need = int(interval / 60)
        return (
            False,
            f"{mode} 上传未到时间：已过 {mins} 分钟（目标 {need} 分钟）",
            mode,
            "",
        )

    if not _git_has_changes(repo_dir):
        state[key]["ts"] = now_ts
        _save_uploader_state(repo_dir, state)
        return False, f"无代码变更，跳过 {mode} 上传", mode, ""

    if args.execute:
        _run_cmd(
            [
                "git",
                "add",
                "-A",
                "--",
                ".",
                ":(exclude).maintenance",
                ":(exclude).maintenance/**",
            ],
            repo_dir,
        )
        commit_msg = f"{args.commit_prefix}: {mode}轮次 {round_count} 上传快照"
        _run_cmd(["git", "commit", "-m", commit_msg], repo_dir)
        _run_cmd(["git", "push"], repo_dir)
        uploaded_tag = ""
        if args.tag_on_upload:
            uploaded_tag = _tag_round_upload(
                repo_dir,
                cycle_version,
                tag_prefix=args.tag_prefix,
            )
        state[key] = {"ts": now_ts, "round": round_count}
        _save_uploader_state(repo_dir, state)
        if uploaded_tag:
            return True, f"{mode} 上传已执行：{commit_msg}，已创建标签 {uploaded_tag}", mode, uploaded_tag
        return True, f"{mode} 上传已执行：{commit_msg}", mode, uploaded_tag

    return (
        False,
        f"到达 {mode} 上传窗口（轮次 {round_count}），建议执行：python scripts/maintenance_uploader.py --execute",
        mode,
        "",
    )


def _read_round_count(state_path: Path, state: dict) -> tuple[int, int, str, str]:
    try:
        round_count, max_round = _parse_round_count(state_path)
        return (
            round_count,
            max_round,
            "state_file",
            "",
        )
    except Exception as exc:
        round_slot = _normalise_round_slot(state.get("last_round_count"))
        # 回退：使用本地持久化的 last_round_count，保持脚本可继续运行
        if round_slot["value"] > 0 and round_slot["max"] > 0:
            return (
                round_slot["value"],
                round_slot["max"],
                "state_fallback",
                str(exc),
            )
        return 0, 100, "parse_failed", str(exc)


def _sync_round_to_state_file(state_path: Path, round_count: int, max_round: int) -> None:
    text = state_path.read_text(encoding="utf-8")
    new_text, count = ROUND_COUNTER_LABEL_PATTERN.subn(
        f"\\g<1>`{round_count}/{max_round}`",
        text,
        count=1,
    )
    if count != 1:
        raise ValueError("未找到可更新的轮次行（docs/context/PROJECT_STATE.md）")
    if new_text == text:
        raise ValueError("轮次更新未发生变化（docs/context/PROJECT_STATE.md）")
    state_path.write_text(new_text, encoding="utf-8")


def _set_round_count(
    repo_dir: Path,
    state_path: Path,
    upload_state: dict,
    *,
    value: int,
    max_round: int,
) -> tuple[int, int, str]:
    if max_round <= 0:
        return 0, max_round, "max_round 必须大于 0"
    value = int(value)
    if value <= 0:
        normalized = 1
    else:
        normalized = value
    if normalized > max_round:
        normalized = max_round

    write_error = ""
    if state_path.exists():
        try:
            _sync_round_to_state_file(state_path, normalized, max_round)
        except Exception as exc:
            write_error = f"同步状态文件失败：{exc}"

    upload_state["last_round_count"] = {
        "value": normalized,
        "max": max_round,
        "updated_at": int(time.time()),
        "source": "cli:set-round",
    }
    _save_uploader_state(repo_dir, upload_state)

    if write_error:
        return normalized, max_round, write_error
    return normalized, max_round, ""


def _advance_round_count(repo_dir: Path, state_path: Path, upload_state: dict) -> tuple[int, int, str]:
    slot = _normalise_round_slot(upload_state.get("last_round_count"))
    max_round = slot.get("max", 100)
    current = slot.get("value", 0)
    next_round = current + 1 if current < max_round else 1
    return _set_round_count(repo_dir, state_path, upload_state, value=next_round, max_round=max_round)


def _run_once(repo_dir: Path, state_file: Path, args: argparse.Namespace) -> None:
    upload_state = _load_uploader_state(repo_dir)
    base_version = _read_project_version(repo_dir)

    if args.set_round is not None and args.advance_round:
        raise SystemExit("不能同时使用 --set-round 和 --advance-round")

    max_round = args.max_round
    round_action = ""
    if args.advance_round:
        round_count, max_round, parse_error = _advance_round_count(repo_dir, state_file, upload_state)
        round_action = "advance"
        round_source = "cli"
    elif args.set_round is not None:
        round_count, max_round, parse_error = _set_round_count(
            repo_dir,
            state_file,
            upload_state,
            value=args.set_round,
            max_round=args.max_round,
        )
        round_action = "set"
        round_source = "cli"
    else:
        round_count, max_round, round_source, parse_error = _read_round_count(state_file, upload_state)
        if round_source == "state_file":
            upload_state["last_round_count"] = {
                "value": round_count,
                "max": max_round,
                "updated_at": int(time.time()),
                "source": "state_file",
            }
            _save_uploader_state(repo_dir, upload_state)
        elif round_source == "parse_failed":
            # 无可回退值时仍返回，可视作未到窗口，避免误触发提交
            round_count = 0
        elif round_source == "state_fallback":
            # 只警告，不影响当前窗口判定
            pass

    # 确保运行时上限一致：避免状态错配导致 100 之外的误判
    if args.max_round > 0:
        max_round = args.max_round
        if round_count > max_round:
            round_count = max_round
        if args.set_round is None and args.advance_round is False and round_source == "state_file":
            upload_state["last_round_count"] = {
                "value": round_count,
                "max": max_round,
                "updated_at": int(time.time()),
                "source": round_source,
            }
            _save_uploader_state(repo_dir, upload_state)

    now_ts = time.time()
    signature = _project_signature(repo_dir)
    upload_state_for_backup = _load_uploader_state(repo_dir)
    backup_path: Path | None
    if signature != upload_state_for_backup.get("last_backup_signature", ""):
        backup_path = _create_backup(repo_dir)
        upload_state_for_backup["last_backup_ts"] = now_ts
        upload_state_for_backup["last_backup_signature"] = signature
        _save_uploader_state(repo_dir, upload_state_for_backup)
    else:
        backup_path = None

    if args.auto_round and round_action == "" and round_source != "parse_failed":
        if backup_path is not None:
            auto_round_count, auto_max_round, round_auto_error = _advance_round_count(
                repo_dir,
                state_file,
                upload_state,
            )
            round_count = auto_round_count
            max_round = auto_max_round
            round_action = "auto"
            if round_auto_error:
                parse_error = f"{parse_error}; auto-round 失败：{round_auto_error}" if parse_error else f"auto-round 失败：{round_auto_error}"

    cycle_version = _derive_cycle_version(
        base_version=base_version,
        round_count=round_count,
        version_step=args.version_step,
    )

    if round_source == "parse_failed":
        uploaded_tag = ""
        uploaded = False
        mode = "error"
        message = f"轮次解析失败：{parse_error}，已跳过上传判断。"
    else:
        upload_args = args
        if args.auto_execute and _classify_upload_type(round_count) != "idle":
            upload_ns = argparse.Namespace(**vars(args))
            upload_ns.execute = True
            upload_args = upload_ns
        uploaded, message, mode, uploaded_tag = _upload_if_due(
            repo_dir,
            round_count,
            now_ts,
            upload_args,
            cycle_version,
        )

    post_upload_state = _load_uploader_state(repo_dir)
    if round_source != "parse_failed":
        next_small_due = _window_due_seconds(
            post_upload_state,
            "last_small_upload",
            args.small_interval_seconds,
            now_ts=now_ts,
        )
        next_major_due = _window_due_seconds(
            post_upload_state,
            "last_major_upload",
            args.major_interval_seconds,
            now_ts=now_ts,
        )
    else:
        next_small_due = 0
        next_major_due = 0

    status = {
        "ts": now_ts,
        "round": round_count,
        "round_max": max_round,
        "mode": mode,
        "project_version": base_version,
        "cycle_version": cycle_version,
        "version_step": args.version_step,
        "cycle_tag": uploaded_tag if uploaded else "",
        "backup_done": bool(backup_path),
        "uploaded": uploaded,
        "message": message,
        "round_action": round_action or "status-only",
        "state_source": round_source if round_action == "" else f"cli:{round_action}",
        "next_small_upload_due_seconds": next_small_due,
        "next_major_upload_due_seconds": next_major_due,
    }
    if parse_error:
        status["parse_error"] = parse_error
        if round_action:
            status["round_action_error"] = parse_error

    print(f"轮次：{round_count}")
    print(f"版本：{cycle_version}")
    print(f"备份：{backup_path or '项目文件无变化，跳过重复备份'}")
    print(f"上传状态：{message}")
    print(f"状态：{json.dumps(status, ensure_ascii=False)}")
    if uploaded:
        print("已按节奏完成自动上传。")


def main() -> None:
    parser = argparse.ArgumentParser(description="按节奏执行项目备份与上传")
    parser.add_argument("--repo", default=".", help="仓库根目录")
    parser.add_argument("--state-file", default="docs/context/PROJECT_STATE.md", help="动态状态文件")
    parser.add_argument("--small-interval-seconds", type=int, default=25 * 60, help="小版本上传间隔")
    parser.add_argument("--major-interval-seconds", type=int, default=120 * 60, help="大版本上传间隔")
    parser.add_argument("--max-round", type=int, default=100, help="轮次窗口上限")
    parser.add_argument("--set-round", type=int, help="手工设置当前窗口计数（0 表示重置为 1；会尝试回写到 PROJECT_STATE.md）")
    parser.add_argument("--advance-round", action="store_true", help="手工将当前窗口计数 +1（达到上限后回绕）")
    parser.add_argument("--auto-round", action="store_true", help="检测到项目变更时自动推进轮次")
    parser.add_argument("--auto-execute", action="store_true", help="到达窗口且满足上传条件时自动执行 git add/commit/push")
    parser.add_argument("--execute", action="store_true", help="允许执行 git add/commit/push（默认仅输出建议）")
    parser.add_argument("--commit-prefix", default="chore", help="上传提交前缀")
    parser.add_argument("--version-step", type=int, default=2, help="版本号每 N 轮递增一次（建议 2）")
    parser.add_argument("--tag-on-upload", action="store_true", help="上传时自动创建并推送版本标签（默认关闭）")
    parser.add_argument("--tag-prefix", default="v", help="标签前缀（例如：v）")
    parser.add_argument("--loop", action="store_true", help="持续循环检测")
    parser.add_argument("--interval-seconds", type=int, default=60, help="循环检查频率")
    args = parser.parse_args()

    if args.max_round <= 0:
        raise SystemExit("--max-round 必须是大于 0 的整数")
    if args.version_step <= 0:
        raise SystemExit("--version-step 必须是大于 0 的整数")

    repo_dir = Path(args.repo).resolve()
    state_path = (repo_dir / args.state_file).resolve()

    if not state_path.exists():
        raise SystemExit(f"未找到状态文件：{state_path}")

    if args.loop:
        while True:
            _run_once(repo_dir, state_path, args)
            time.sleep(max(1, args.interval_seconds))
    else:
        _run_once(repo_dir, state_path, args)


if __name__ == "__main__":
    main()
