# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_phase_c_guard_contract_has_required_markers() -> None:
    text = (REPO_ROOT / "contract" / "PHASE_C_MEMORY_GUARD_CONTRACT_V1.md").read_text(encoding="utf-8")
    assert "PHASE_C_MEMORY_GUARD_CONTRACT_V1" in text
    assert "phase_c_guard_routing_sync=ok" in text
    assert "phase_c_owner_execution_path=ok" in text
    assert "bridge_policy:c2_bridge_only=ack" in text
    assert "phase_c_governance_checks=ok" in text


def test_phase_c_guard_plan_exists_and_matches_contract() -> None:
    text = (REPO_ROOT / "GUARD_HEAL" / "Plans" / "PHASEC_MEMORY_GUARD_ROUTING_SYNC_2026-03-05.md").read_text(encoding="utf-8")
    assert "phase_c_guard_routing_sync=ok" in text
    assert "phase_c_owner_execution_path=ok" in text
    assert "bridge_policy:c2_bridge_only=ack" in text


def test_memory_mode_wiring_exists_in_test_entrypoint() -> None:
    text = (REPO_ROOT / "scripts" / "test_entrypoint.sh").read_text(encoding="utf-8")
    assert "--memory" in text
    assert "test_phase_c_memory_guard_contract.py" in text
