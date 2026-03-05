from pathlib import Path
REPO_ROOT = Path(__file__).resolve().parents[1]

def test_phase_f_guard_markers() -> None:
    text = (REPO_ROOT / "contract" / "PHASE_F_P0_SAFETY_GUARD_CONTRACT_V1.md").read_text(encoding="utf-8")
    assert "phase_f_p0_safety_guard_contract=ok" in text
    assert "phase_f_circuit_breaker_guard_path=ok" in text
    assert "phase_f_hard_stop_guard_path=ok" in text
    assert "phase_f_manual_reauth_guard_path=ok" in text

def test_p0_safety_mode_wiring_exists() -> None:
    text = (REPO_ROOT / "scripts" / "test_entrypoint.sh").read_text(encoding="utf-8")
    assert "--p0-safety" in text
    assert "test_phase_f_p0_safety_guard_contract.py" in text
