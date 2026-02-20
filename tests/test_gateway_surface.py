from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_gateway_scripts_exist_and_executable():
    scripts = [
        "scripts/gateway_io.sh",
        "scripts/gateway_verify_all_repos.sh",
        "scripts/publish_public_gateway_packets.sh",
    ]
    for rel in scripts:
        path = REPO_ROOT / rel
        assert path.exists(), f"missing {rel}"
        assert path.stat().st_mode & 0o111, f"script not executable: {rel}"


def test_gateway_io_contract_commands_present():
    text = (REPO_ROOT / "scripts/gateway_io.sh").read_text(encoding="utf-8")
    assert "verify_github" in text
    assert "verify_onedrive" in text
    assert "verify_gworkspace" in text
    assert "do_export" in text
    assert "do_import" in text
    assert "Usage: $0 [verify|export|import <archive>]" in text
