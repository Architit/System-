#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERN_PROFILE="${AESS_PATTERN_PROFILE:-$SCRIPT_DIR/AESS_PATTERN_PROFILE_TRINITY_GOLDEN_V1.env}"
if [[ -f "$PATTERN_PROFILE" ]]; then
  # Optional non-destructive pattern profile for orchestration semantics.
  # shellcheck disable=SC1090
  source "$PATTERN_PROFILE"
fi

WORK_ROOT="${AESS_WORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
STATE_ROOT="${AESS_STATE_ROOT:-/tmp/aess_autostart}"
LOG_DIR="$STATE_ROOT/logs"
PID_DIR="$STATE_ROOT/pids"
LOCK_FILE="$STATE_ROOT/boot.lock"
STAMP_FILE="$STATE_ROOT/last_boot_epoch"
COOLDOWN_SEC="${AESS_COOLDOWN_SEC:-300}"
MAX_RETRIES="${AESS_MAX_RETRIES:-2}"
RETRY_DELAY_SEC="${AESS_RETRY_DELAY_SEC:-2}"
HOLD_FAIL_THRESHOLD="${AESS_HOLD_FAIL_THRESHOLD:-3}"
LAM_PORT="${AESS_LAM_PORT:-8080}"
PHASE_FILE="$STATE_ROOT/phase.state"
HOLD_FILE="$STATE_ROOT/HOLD"
HOLD_REASON_FILE="$STATE_ROOT/HOLD.reason"
FAIL_COUNT_DIR="$STATE_ROOT/fail_counts"
EVIDENCE_LOG="$LOG_DIR/evidence_$(date +%Y%m%d_%H%M%S).log"
DIRTY_LOG="$LOG_DIR/dirty_state_$(date +%Y%m%d_%H%M%S).log"
AESS_PATTERN_TRINITY="${AESS_PATTERN_TRINITY:-0}"
AESS_PATTERN_GOLDEN_RATIO="${AESS_PATTERN_GOLDEN_RATIO:-0}"
AESS_PATTERN_DRGN_MD="${AESS_PATTERN_DRGN_MD:-0}"
AESS_TRINITY_PHASES="${AESS_TRINITY_PHASES:-3}"
AESS_GOLDEN_RATIO_PHI="${AESS_GOLDEN_RATIO_PHI:-1.6180339887}"
AESS_DRGN_MD_PROFILE_ID="${AESS_DRGN_MD_PROFILE_ID:-drgn-md-v1}"
AESS_PHASE_WEIGHTS="${AESS_PHASE_WEIGHTS:-0.382,0.236,0.382}"
AESS_PHASE_PROFILE_ID="${AESS_PHASE_PROFILE_ID:-trinity-golden-v1}"

mkdir -p "$STATE_ROOT" "$LOG_DIR" "$PID_DIR" "$FAIL_COUNT_DIR"
touch "$LOCK_FILE"

set_phase() {
  local phase="$1"
  echo "$phase" > "$PHASE_FILE"
  echo "phase=$phase" | tee -a "$summary_log" "$EVIDENCE_LOG"
}

emit_evidence() {
  local code="$1"
  local details="$2"
  echo "evidence code=$code ts=$(date -Iseconds) $details" | tee -a "$EVIDENCE_LOG"
}

activate_hold() {
  local reason="$1"
  touch "$HOLD_FILE"
  echo "$reason" > "$HOLD_REASON_FILE"
  emit_evidence "HOLD_ACTIVATED" "reason=\"$reason\""
  echo "HOLD activated: $reason" | tee -a "$summary_log"
}

record_failure() {
  local name="$1"
  local reason="$2"
  local count_file="$FAIL_COUNT_DIR/${name}.count"
  local count=0
  if [[ -f "$count_file" ]]; then
    count="$(cat "$count_file" 2>/dev/null || echo 0)"
  fi
  if [[ ! "$count" =~ ^[0-9]+$ ]]; then
    count=0
  fi
  count=$((count + 1))
  echo "$count" > "$count_file"
  emit_evidence "FAILURE" "component=$name reason=$reason count=$count"
  if (( count >= HOLD_FAIL_THRESHOLD )); then
    activate_hold "component=$name reason=$reason count=$count threshold=$HOLD_FAIL_THRESHOLD"
  fi
}

record_success() {
  local name="$1"
  local count_file="$FAIL_COUNT_DIR/${name}.count"
  if [[ -f "$count_file" ]]; then
    rm -f "$count_file"
  fi
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "aess_bootstrap: lock is active, skipping duplicate startup"
  exit 0
fi

now_epoch="$(date +%s)"
if [[ -f "$STAMP_FILE" ]]; then
  last_epoch="$(cat "$STAMP_FILE" 2>/dev/null || echo 0)"
  if [[ "$last_epoch" =~ ^[0-9]+$ ]]; then
    delta=$(( now_epoch - last_epoch ))
    if (( delta < COOLDOWN_SEC )); then
      echo "aess_bootstrap: cooldown active (${delta}s < ${COOLDOWN_SEC}s), skipping"
      exit 0
    fi
  fi
fi
echo "$now_epoch" > "$STAMP_FILE"

summary_log="$LOG_DIR/boot_summary_$(date +%Y%m%d_%H%M%S).log"
echo "aess_bootstrap started at $(date -Iseconds)" | tee -a "$summary_log"
echo "work_root=$WORK_ROOT" | tee -a "$summary_log"
echo "phase_profile_id=$AESS_PHASE_PROFILE_ID trinity=$AESS_PATTERN_TRINITY golden_ratio=$AESS_PATTERN_GOLDEN_RATIO drgn_md=$AESS_PATTERN_DRGN_MD drgn_md_profile_id=$AESS_DRGN_MD_PROFILE_ID phases=$AESS_TRINITY_PHASES weights=$AESS_PHASE_WEIGHTS phi=$AESS_GOLDEN_RATIO_PHI" | tee -a "$summary_log"

if [[ -f "$HOLD_FILE" ]]; then
  reason="$(cat "$HOLD_REASON_FILE" 2>/dev/null || echo "unknown")"
  echo "HOLD active: $reason" | tee -a "$summary_log"
  emit_evidence "HOLD_ACTIVE_SKIP" "reason=\"$reason\""
  echo "aess_bootstrap finished: started=0 skipped=0 failed=0 hold=1" | tee -a "$summary_log"
  exit 0
fi

set_phase "INIT"

if [[ ! -d "$WORK_ROOT" ]]; then
  echo "ERROR: work root not found: $WORK_ROOT" | tee -a "$summary_log"
  emit_evidence "WORK_ROOT_MISSING" "path=$WORK_ROOT"
  exit 1
fi

set_phase "DISCOVER"
mapfile -t repos < <(find "$WORK_ROOT" -mindepth 1 -maxdepth 1 -type d -exec test -d "{}/.git" ';' -print | sort)

if (( ${#repos[@]} == 0 )); then
  echo "No git repos found under $WORK_ROOT" | tee -a "$summary_log"
  exit 0
fi

{
  echo "dirty_state_scan_started=$(date -Iseconds)"
  for repo in "${repos[@]}"; do
    name="$(basename "$repo")"
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    status="$(git -C "$repo" status --porcelain 2>/dev/null || true)"
    if [[ -n "$status" ]]; then
      echo "repo=$name branch=$branch state=DIRTY"
      printf '%s\n' "$status" | sed 's/^/  /'
      emit_evidence "DIRTY_STATE" "repo=$name branch=$branch"
    else
      echo "repo=$name branch=$branch state=CLEAN"
    fi
  done
  echo "dirty_state_scan_finished=$(date -Iseconds)"
} > "$DIRTY_LOG"
echo "dirty-state snapshot: $DIRTY_LOG" | tee -a "$summary_log"

started=0
skipped=0
failed=0

start_repo_hook() {
  local repo="$1"
  local name="$2"
  local hook="$3"
  local repo_log="$LOG_DIR/${name}.log"
  local attempt started_ok=0 max_attempts=$((MAX_RETRIES + 1))
  for (( attempt=1; attempt<=max_attempts; attempt++ )); do
    if bash -lc "cd \"$repo\" && \"$hook\"" >>"$repo_log" 2>&1; then
      echo "STARTED hook: $name ($hook) attempt=$attempt" | tee -a "$summary_log"
      started_ok=1
      break
    fi
    echo "RETRY hook: $name attempt=$attempt/$max_attempts" | tee -a "$summary_log"
    if (( attempt < max_attempts )); then
      sleep "$RETRY_DELAY_SEC"
    fi
  done
  if (( started_ok == 1 )); then
    record_success "$name"
    ((started+=1))
  else
    echo "FAILED hook: $name ($hook)" | tee -a "$summary_log"
    record_failure "$name" "HOOK_START_FAILED"
    ((failed+=1))
  fi
}

start_lam_core() {
  local repo="$1"
  local name="$2"
  local repo_log="$LOG_DIR/${name}_core.log"
  local pid_file="$PID_DIR/${name}_core.pid"

  if [[ -f "$pid_file" ]]; then
    local existing_pid
    existing_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ "$existing_pid" =~ ^[0-9]+$ ]] && kill -0 "$existing_pid" 2>/dev/null; then
      echo "SKIP LAM core: already running pid=$existing_pid" | tee -a "$summary_log"
      ((skipped+=1))
      return
    fi
  fi

  if [[ ! -x "$repo/scripts/lam_env.sh" ]]; then
    echo "FAILED LAM core: missing scripts/lam_env.sh" | tee -a "$summary_log"
    record_failure "$name" "MISSING_ENV_SCRIPT"
    ((failed+=1))
    return
  fi

  if [[ ! -d "$repo/.venv" ]]; then
    echo "SKIP LAM core: .venv missing in $repo (run devkit/bootstrap.sh once)" | tee -a "$summary_log"
    ((skipped+=1))
    return
  fi

  if [[ ! -f "$repo/tma.yaml" ]]; then
    echo "FAILED LAM core: missing $repo/tma.yaml" | tee -a "$summary_log"
    record_failure "$name" "MISSING_CONFIG"
    ((failed+=1))
    return
  fi

  local pid attempt started_ok=0 max_attempts=$((MAX_RETRIES + 1))
  for (( attempt=1; attempt<=max_attempts; attempt++ )); do
    if nohup bash -lc "cd \"$repo\" && bash scripts/lam_env.sh python -m tma.api" >>"$repo_log" 2>&1 & then
      pid=$!
      sleep 2
      if kill -0 "$pid" 2>/dev/null; then
        echo "$pid" > "$pid_file"
        echo "STARTED LAM core API: pid=$pid attempt=$attempt" | tee -a "$summary_log"
        started_ok=1
        break
      fi
    fi
    echo "RETRY LAM core: attempt=$attempt/$max_attempts" | tee -a "$summary_log"
    if (( attempt < max_attempts )); then
      sleep "$RETRY_DELAY_SEC"
    fi
  done

  if (( started_ok == 1 )); then
    record_success "$name"
    ((started+=1))
  else
    echo "FAILED LAM core startup: process exited early (see $repo_log)" | tee -a "$summary_log"
    if tail -n 30 "$repo_log" 2>/dev/null | rg -q "could not bind on any address|Address already in use"; then
      record_failure "$name" "PORT_IN_USE"
    else
      record_failure "$name" "EARLY_EXIT"
    fi
    ((failed+=1))
  fi
}

set_phase "START"
for repo in "${repos[@]}"; do
  if [[ -f "$HOLD_FILE" ]]; then
    echo "HOLD active during START; stop launching remaining repos" | tee -a "$summary_log"
    break
  fi
  name="$(basename "$repo")"

  if [[ -x "$repo/scripts/aess_autostart.sh" ]]; then
    start_repo_hook "$repo" "$name" "./scripts/aess_autostart.sh"
    continue
  fi

  if [[ -x "$repo/autostart.sh" ]]; then
    start_repo_hook "$repo" "$name" "./autostart.sh"
    continue
  fi

  if [[ "$name" == "LAM" ]]; then
    start_lam_core "$repo" "$name"
    continue
  fi

  echo "SKIP $name: no autostart hook configured" | tee -a "$summary_log"
  ((skipped+=1))
done

set_phase "VERIFY"
if (( failed > 0 )); then
  emit_evidence "BOOT_HAS_FAILURES" "started=$started skipped=$skipped failed=$failed"
fi
if [[ -f "$HOLD_FILE" ]]; then
  set_phase "HOLD"
else
  set_phase "DONE"
fi
echo "aess_bootstrap finished: started=$started skipped=$skipped failed=$failed hold=$([[ -f "$HOLD_FILE" ]] && echo 1 || echo 0)" | tee -a "$summary_log"
