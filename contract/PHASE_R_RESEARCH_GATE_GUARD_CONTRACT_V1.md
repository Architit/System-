# PHASE_R_RESEARCH_GATE_GUARD_CONTRACT_V1

status: ACTIVE
derivation_mode: DERIVATION_ONLY

## Scope
- repository: `System-`
- phase: `R` (Research Gate)
- task_id: `phaseR_system_wave1_execution`

## Required Markers
- `phase_r_research_gate_guard_contract=ok`
- `phase_r_transport_benchmark_matrix=ok`
- `phase_r_vector_engine_benchmark_matrix=ok`
- `phase_r_wake_on_demand_trigger_guard=ok`

## Benchmark Matrix
- transport: `ZeroMQ` vs `gRPC` vs `FastAPI`
- vector engine: `FAISS` vs `LanceDB` vs `SQLite-vec/SQLite-VSS`
- wake-on-demand: guard-level trigger readiness + cold-start latency tuple

## Fail-Fast
- missing benchmark dimension => `BLOCKED`
- missing comparable metrics => `BLOCKED`
- missing owner evidence tuple => `BLOCKED`
