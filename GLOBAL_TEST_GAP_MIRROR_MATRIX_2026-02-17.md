# Global Test Gap Mirror Matrix — 2026-02-17

## Current Test Surface (refreshed 2026-02-17 04:17 UTC)
| Repository | `tests/*` files | `tests/*.py` files | `scripts/test_entrypoint.sh` |
|---|---:|---:|---|
| Archivator_Agent | 5 | 5 | present |
| CORE | 6 | 6 | present |
| J.A.R.V.I.S | 4 | 4 | present |
| LAM-Codex_Agent | 8 | 5 | present |
| LAM | 49 | 49 | present |
| LAM_Comunication_Agent | 2 | 2 | present |
| LAM_DATA_Src | 5 | 5 | present |
| LAM_Test_Agent | 13 | 8 | present |
| Operator_Agent | 6 | 6 | present |
| RADRILONIUMA-PROJECT | 3 | 3 | present |
| Roaudter-agent | 17 | 17 | present |
| System- | 4 | 4 | present |
| TRIANIUMA_DATA_BASE | 6 | 6 | present |
| Trianiuma | 6 | 6 | present |
| Trianiuma_MEM_CORE | 6 | 6 | present |

## Priority Expansion Targets (Next Wave)
- Add malformed-archive (existing but invalid tgz) tests for gateway import flows in all data/control repos.
- Add strict/warn policy branch tests for daily automation wrappers.
- Add schema-level checks for machine-readable policy fragments where available.

## Outcome
- Entry-point parity complete for active workspace: `15/15` repositories have standardized `scripts/test_entrypoint.sh`.
- Baseline floor reached and maintained: all 15 active repositories are now at `>=10` tests.
