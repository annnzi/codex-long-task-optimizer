import json
import zipfile

import scripts.maintenance_uploader as maintenance_uploader
from scripts.maintenance_uploader import (
    _create_backup,
    _derive_cycle_version,
    _git_has_unpushed_commits,
    _git_sensitive_paths,
    _load_uploader_state,
    _save_uploader_state,
    _sync_round_to_state_file,
)


def test_cycle_version_uses_project_version_without_round_double_count() -> None:
    assert (
        _derive_cycle_version(
            "0.1.8",
            18,
            version_step=2,
            cycles_completed=0,
            max_round=100,
        )
        == "0.1.8"
    )


def test_uploader_state_is_replaced_as_complete_json(tmp_path) -> None:
    _save_uploader_state(
        tmp_path,
        {
            "last_backup_signature": "stable",
            "last_round_count": {"value": 22, "max": 100},
            "pending_tag": "v0.2.4",
        },
    )

    state = _load_uploader_state(tmp_path)

    assert state["last_backup_signature"] == "stable"
    assert state["last_round_count"]["value"] == 22
    assert state["pending_tag"] == "v0.2.4"
    assert not (tmp_path / ".maintenance" / "upload_state.json.tmp").exists()


def test_backup_contains_machine_readable_manifest(tmp_path) -> None:
    backup_path = _create_backup(
        tmp_path,
        marker="r23-v0.2.1",
        project_signature="abc123",
    )

    with zipfile.ZipFile(backup_path) as archive:
        manifest = json.loads(archive.read("backup-manifest.json"))

    assert manifest["format"] == 1
    assert manifest["marker"] == "r23-v0.2.1"
    assert manifest["project_signature"] == "abc123"
    assert manifest["file_count"] >= 0


def test_unpushed_commit_detection_reads_branch_ahead(monkeypatch, tmp_path) -> None:
    monkeypatch.setattr(
        maintenance_uploader.subprocess,
        "check_output",
        lambda *args, **kwargs: "# branch.head main\n# branch.ab +1 -0\n",
    )

    assert _git_has_unpushed_commits(tmp_path)


def test_sensitive_file_guard_ignores_safe_templates(monkeypatch, tmp_path) -> None:
    monkeypatch.setattr(
        maintenance_uploader,
        "_git_project_status",
        lambda repo_dir: "?? .env\n?? .env.example\n?? keys/server.pem\n?? README.md\n",
    )

    assert _git_sensitive_paths(tmp_path) == [".env", "keys/server.pem"]


def test_round_state_update_replaces_complete_markdown(tmp_path) -> None:
    state_path = tmp_path / "PROJECT_STATE.md"
    state_path.write_text("当前窗口计数 `1/100`\n", encoding="utf-8")

    _sync_round_to_state_file(state_path, 27, 100)

    assert state_path.read_text(encoding="utf-8") == "当前窗口计数 `27/100`\n"
    assert not (tmp_path / "PROJECT_STATE.md.tmp").exists()
