# PHASE_E_FLOW_CONTROL_GUARD_CONTRACT_V1

## Scope
- owner_repo: `System-`
- phase: `PHASE_E_WAVE_1`
- task_id: `phaseE_system_flow_control_wave1_execution`
- status: `DONE`

## Objective
Synchronize flow-control guard markers (CBFC/heartbeat/outlier isolation) for Phase E wave-1.

## Required Markers
- `phase_e_flow_control_guard_contract=ok`
- `phase_e_cbfc_guard_path=ok`
- `phase_e_heartbeat_guard_path=ok`
- `phase_e_outlier_guard_path=ok`

## Test Wiring Contract
- `scripts/test_entrypoint.sh --flow-control` MUST execute Phase E flow-control guard checks.
- `scripts/test_entrypoint.sh --patch-runtime` MUST remain green as non-regression gate.

## Constraints
- derivation_only execution
- fail-fast on violated preconditions
- no-new-agents-or-repos
