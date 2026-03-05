# PHASE_C_MEMORY_GUARD_CONTRACT_V1

## Scope
- owner_repo: `System-`
- phase: `PHASE_C_WAVE_1`
- task_id: `phaseC_system_wave1_guard_routing_sync`
- status: `DONE`

## Objective
Synchronize guard/routing pointers for Phase C memory wave without expanding scope.

## Required Markers
- `phase_c_guard_routing_sync=ok`
- `phase_c_owner_execution_path=ok`
- `bridge_policy:c2_bridge_only=ack`
- `phase_c_governance_checks=ok`

## Test Wiring Contract
- `scripts/test_entrypoint.sh --memory` MUST execute `tests/test_phase_c_memory_guard_contract.py`.
- `scripts/test_entrypoint.sh --patch-runtime` MUST remain green as non-regression gate.

## Constraints
- derivation_only execution
- fail-fast on violated preconditions
- no-new-agents-or-repos
