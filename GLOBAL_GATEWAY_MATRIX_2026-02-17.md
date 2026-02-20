# Global Gateway Matrix — 2026-02-17

## Scope
Unified gateway coverage for GitHub / OneDrive / Google Workspace across all git repositories in /home/architit/work.

## Status Table

| Repository | Contract | Script | GitHub Gateway | OneDrive Gateway | Google Workspace Gateway |
|---|---|---|---|---|---|
| Archivator_Agent | yes | yes | ok | warn | warn |
| CORE | yes | yes | ok | warn | warn |
| CORE_RECLONE_CLEAN | yes | yes | ok | warn | warn |
| J.A.R.V.I.S | yes | yes | ok | warn | warn |
| LAM | yes | yes | ok | warn | warn |
| LAM-Codex_Agent | yes | yes | ok | warn | warn |
| LAM_Comunication_Agent | yes | yes | ok | warn | warn |
| LAM_DATA_Src | yes | yes | ok | warn | warn |
| LAM_Test_Agent | yes | yes | ok | warn | warn |
| Operator_Agent | yes | yes | ok | warn | warn |
| RADRILONIUMA-PROJECT | yes | yes | ok | warn | warn |
| Roaudter-agent | yes | yes | ok | warn | warn |
| System- | yes | yes | ok | warn | warn |
| TRIANIUMA_DATA_BASE | yes | yes | ok | warn | warn |
| Trianiuma | yes | yes | ok | warn | warn |
| Trianiuma_MEM_CORE | yes | yes | ok | warn | warn |

## Notes
- `warn` for OneDrive/Google Workspace means env path not configured in this runtime (gateway exists, path not bound).
- GitHub gateway `ok` means configured remote is present and readable via git config.
- Export/import interface for every repo: `scripts/gateway_io.sh [verify|export|import <archive>]`.
