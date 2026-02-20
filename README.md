# System Aggregator (NTFS junction repo)

Репозиторий агрегирует системные каталоги через **NTFS junction**.
Правила: не линкуем весь `C:\System`, не ссылаемся внутрь репо; секреты/мусор игнорируются.

## Junctions
- `CORE`           → `C:\System\CORE`
- `TRI_CORE`       → `C:\System\CORE\Trianiuma\CORE`
- `AUTOPILOT_CORE` → `C:\System\CORE\Trianiuma\CORE\Autopilot\CORE`
- `CHANNEL_CORE`   → `C:\System\CORE\Trianiuma\CORE\Channel\CORE`
- `GUARD_HEAL`     → `C:\System\CORE\Trianiuma\CORE\GUARD_HEAL`

## Коммиты/пуш
- LFS включён для: `*.zip *.7z *.rar *.iso *.tar *.gz *.bin`
- Pre-commit блокирует >100 MB и потенциальные секреты.

## Testing
- `scripts/test_entrypoint.sh --all`
- `scripts/test_entrypoint.sh --governance`
- `scripts/test_entrypoint.sh --gateway`
- `scripts/test_entrypoint.sh --channel`
