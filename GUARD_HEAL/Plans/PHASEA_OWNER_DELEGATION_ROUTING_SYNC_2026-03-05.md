# PHASE A SYSTEM GUARD IDENTITY/ROUTING SYNC

- date: `2026-03-05`
- task_id: `phaseA_t012_system_guard_identity_routing_sync`
- scope: `System- / GUARD_HEAL / Plans`
- depends_on: `phaseA_t007_jarvis_target_resolution_hardening`

## Objective
Synchronize ecosystem guard plans with deterministic routing constraints and owner-map delegation boundaries for Phase A.

## Guard Rules
1. `identity`: each execution target must resolve to canonical `system_id` before dispatch.
2. `owner`: owner map is authoritative for task delegation and repository write scope.
3. `delegation`: cross-repo delegation requires explicit owner-map path and task_id.
4. `routing`: deterministic routing only; unresolved targets are blocked fail-fast.
5. `phase A`: no-new-agents policy remains active for all local integration tasks.

## Deterministic Constraints
1. No global recursive writes without explicit authorization.
2. Route selection must use deterministic target resolution (system_id/subtree_prefix).
3. On ambiguity: emit fail-fast `target_resolution_failed` and stop.

## Evidence Anchors
1. `TASK_SPEC_PACK_PHASE_A_V1.md`
2. `ORCHESTRATION_TARGET_RESOLUTION_PROTOCOL.md` (J.A.R.V.I.S)
3. `LOCAL_INTEGRATION_DELEGATION_PLAN_V1.md`
