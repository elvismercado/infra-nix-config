#!/usr/bin/env bash
set -Eeuo pipefail

public_repo=""
current_operation="not started"
current_hostname=""
target_platform="linux"
staged_status="not run"
remote_has_changes="unknown"
sudo_keepalive_pid=""
log_file=""
phase="not started"
private_status="not run"
lock_status="not run"
build_status="not run"
switch_status="not run"
public_status="not run"
host_results=()

usage() {
  cat <<'USAGE'
Usage:
  switch-workflow.sh upgrade <public-repo> <private-repo> <hostname> <linux|darwin>
  switch-workflow.sh auto-boot <public-repo> <hostname>
  switch-workflow.sh publish-public <public-repo>
  switch-workflow.sh publish-private <private-repo>
  switch-workflow.sh build-all <public-repo> <linux|darwin> [hostname]
  switch-workflow.sh logs
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  return 1
}

send_notification() {
  local title="$1"
  local message="$2"
  local urgency="${3:-normal}"
  local expire_time_ms="${4:-20000}"

  if [[ "${target_platform:-linux}" == "darwin" ]]; then
    if command -v osascript >/dev/null 2>&1; then
      osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" 2>/dev/null || true
    fi
    return 0
  fi

  if ! command -v notify-send >/dev/null 2>&1; then
    return 0
  fi

  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    if command -v loginctl >/dev/null 2>&1; then
      local sessions
      sessions=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}')
      for session in $sessions; do
        local user uid type
        user=$(loginctl show-session "$session" -p Name --value 2>/dev/null || true)
        uid=$(loginctl show-session "$session" -p User --value 2>/dev/null || true)
        type=$(loginctl show-session "$session" -p Type --value 2>/dev/null || true)
        if [[ -n "$user" && -n "$uid" && ( "$type" == "wayland" || "$type" == "x11" ) ]]; then
          sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
            notify-send \
              --urgency="$urgency" \
              --expire-time="$expire_time_ms" \
              --app-name="Nix Auto-Upgrade" \
              --icon="system-software-update" \
              "$title" \
              "$message" 2>/dev/null || true
        fi
      done
    fi
  else
    notify-send \
      --urgency="$urgency" \
      --expire-time="$expire_time_ms" \
      --app-name="Nix Workflow" \
      --icon="system-software-update" \
      "$title" \
      "$message" 2>/dev/null || true
  fi
}

finish() {
  local exit_code="$1"
  local result="success"
  if [[ "$exit_code" -ne 0 ]]; then
    result="failed"
  fi

  # Terminate background sudo keepalive if running
  if [[ -n "${sudo_keepalive_pid:-}" ]]; then
    kill "$sudo_keepalive_pid" 2>/dev/null || true
    wait "$sudo_keepalive_pid" 2>/dev/null || true
  fi

  # Rollback flake.lock if upgrade failed after updating inputs
  if [[ -n "${public_repo:-}" && -f "${public_repo}/flake.lock.upgrade-bak" ]]; then
    if [[ "$exit_code" -ne 0 ]]; then
      if [[ -n "$log_file" && -f "${public_repo}/flake.lock" ]]; then
        cp "${public_repo}/flake.lock" "${log_file%.log}.flake.lock.failed" 2>/dev/null || true
      fi
      cp "${public_repo}/flake.lock.upgrade-bak" "${public_repo}/flake.lock"
      rm -f "${public_repo}/flake.lock.upgrade-bak"
      lock_status="rolled back to pre-upgrade state"
    else
      rm -f "${public_repo}/flake.lock.upgrade-bak"
    fi
  fi

  # Clean up any leftover build symlink in repository root
  if [[ -n "${public_repo:-}" ]]; then
    rm -f "${public_repo}/result"
  fi

  printf '\n=== Workflow summary ===\n'
  printf 'result: %s\n' "$result"
  printf 'last phase: %s\n' "$phase"
  printf 'private repository: %s\n' "$private_status"
  printf 'flake inputs: %s\n' "$lock_status"
  printf 'host builds: %s\n' "$build_status"
  if [[ ${#host_results[@]} -gt 0 ]]; then
    printf '  per-host details:\n'
    for hr in "${host_results[@]}"; do
      printf '    - %s\n' "$hr"
    done
  fi
  printf 'system switch: %s\n' "$switch_status"
  printf 'public repository: %s\n' "$public_status"
  printf 'finished: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
  if [[ -n "$log_file" ]]; then
    printf 'log file: %s\n' "$log_file"
    if [[ -f "${log_file%.log}.flake.lock.failed" ]]; then
      printf 'failed lockfile preserved: %s\n' "${log_file%.log}.flake.lock.failed"
    fi
  fi

  # Send desktop notifications: sticky (0) on failure, timed (20000ms) on successful staging/upgrade
  if [[ "$exit_code" -ne 0 ]]; then
    if [[ "$current_operation" != "not started" && -n "$current_operation" ]]; then
      send_notification \
        "System Update Failed" \
        "Workflow '${current_operation}' failed during phase '${phase}'. Run switchhealth or check logs." \
        "critical" \
        0
    fi
  else
    if [[ "$current_operation" == "auto-boot" ]]; then
      if [[ "$staged_status" == "staged" ]]; then
        send_notification \
          "System Update Staged (Next Boot)" \
          "New system generation built in background for ${current_hostname:-system}. Changes take effect on next reboot." \
          "normal" \
          20000
      fi
    elif [[ "$current_operation" == "upgrade" ]]; then
      send_notification \
        "Infra Nix Upgrade: Complete" \
        "Successfully validated all hosts and activated ${current_hostname:-system}." \
        "normal" \
        20000
    elif [[ "$current_operation" == "build-all" ]]; then
      send_notification \
        "Infra Nix Build: Complete" \
        "All ${target_platform:-platform} hosts built successfully." \
        "normal" \
        10000
    fi
  fi
}

trap 'exit_code=$?; finish "$exit_code"' EXIT

start_log() {
  current_operation="$1"
  local host="${2:-all}"
  current_hostname="$host"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/infra-nix-config/upgrade"
  local timestamp
  timestamp="$(date '+%Y-%m-%dT%H-%M-%S')"
  mkdir -p "$state_dir"
  log_file="${state_dir}/${timestamp}-${host}-${current_operation}.log"
  exec > >(tee -a "$log_file") 2>&1
  printf '=== Infra Nix workflow ===\n'
  printf 'operation: %s\n' "$current_operation"
  printf 'host: %s\n' "$host"
  printf 'started: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
  printf 'log file: %s\n' "$log_file"
}

run_phase() {
  phase="$1"
  shift
  printf '\n=== %s ===\n' "$phase"
  "$@"
  printf 'phase result: success\n'
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

validate_platform() {
  case "$1" in
    linux|darwin) ;;
    *) fail "Unsupported platform: $1" ;;
  esac
}

is_git_repo() {
  git -C "$1" rev-parse --git-dir >/dev/null 2>&1
}

has_origin() {
  git -C "$1" remote get-url origin >/dev/null 2>&1
}

git_is_dirty() {
  [[ -n "$(git -C "$1" status --porcelain)" ]]
}

commit_all_if_dirty() {
  local repo="$1"
  local message="$2"
  if ! git_is_dirty "$repo"; then
    return 1
  fi
  git -C "$repo" add --all
  git -C "$repo" commit -m "$message"
  return 0
}

check_common_commands() {
  require_command date
  require_command git
  require_command tee
}

check_nix_commands() {
  require_command gh
  require_command nix
}

load_github_token() {
  local github_token=""
  if command -v gh >/dev/null 2>&1; then
    github_token="$(gh auth token 2>/dev/null || true)"
    if [[ -z "$github_token" && ${EUID:-$(id -u)} -eq 0 && -n "${public_repo:-}" ]]; then
      local repo_owner
      repo_owner="$(stat -c '%U' "$public_repo" 2>/dev/null || true)"
      if [[ -n "$repo_owner" ]]; then
        github_token="$(sudo -u "$repo_owner" gh auth token 2>/dev/null || true)"
      fi
    fi
  fi
  if [[ -z "$github_token" && -n "${GITHUB_TOKEN:-}" ]]; then
    github_token="$GITHUB_TOKEN"
  fi

  if [[ -n "$github_token" ]]; then
    nix_auth_args=(--option access-tokens "github.com=${github_token}")
  else
    nix_auth_args=()
  fi
}

publish_private_impl() {
  local private_repo="$1"

  if [[ ! -d "$private_repo" ]] || ! is_git_repo "$private_repo"; then
    private_status="not configured"
    printf 'Private sibling is missing; GitHub remains the private input source.\n'
    return 0
  fi

  if ! has_origin "$private_repo"; then
    if git_is_dirty "$private_repo"; then
      private_status="blocked: local changes have no origin"
      fail "Private sibling has local changes but no origin remote"
    fi
    private_status="stub or local-only checkout"
    printf 'Private sibling has no origin and is clean; skipping publish.\n'
    return 0
  fi

  local committed="no"
  if commit_all_if_dirty "$private_repo" "chore(private): publish local changes"; then
    committed="yes"
    private_status="committed locally"
  fi
  if [[ "$private_status" == "not run" ]]; then
    private_status="already clean"
  fi

  if ! git -C "$private_repo" pull --verbose --rebase; then
    git -C "$private_repo" rebase --abort 2>/dev/null || true
    private_status="${private_status}; pull/rebase failed (rebase aborted cleanly)"
    fail "Failed to rebase private repository with origin. Rebase was cleanly aborted."
  fi
  private_status="${private_status:-already clean}; pulled"
  if ! git -C "$private_repo" push --verbose; then
    private_status="${private_status}; push failed"
    return 1
  fi
  if [[ "$committed" == "yes" ]]; then
    private_status="committed and pushed"
  else
    private_status="already synchronized"
  fi
}

prepare_public_impl() {
  local repo="$1"

  if git_is_dirty "$repo"; then
    public_status="blocked: uncommitted changes"
    fail "Public repository has uncommitted changes. Commit, stash, or reset them before running upgrade."
  fi
  public_status="clean"

  if ! git -C "$repo" pull --verbose --rebase; then
    git -C "$repo" rebase --abort 2>/dev/null || true
    public_status="pull/rebase failed (rebase aborted cleanly)"
    fail "Failed to rebase public repository with origin. Rebase was cleanly aborted."
  fi
  public_status="clean and synchronized"
}

update_flake_impl() {
  local repo="$1"
  lock_status="updating"
  cp "$repo/flake.lock" "$repo/flake.lock.upgrade-bak"
  (
    cd "$repo"
    nix flake update "${nix_auth_args[@]}" --show-trace -v
  )
  lock_status="updated"
}

check_flake_impl() {
  local repo="$1"
  nix flake check "$repo" "${nix_auth_args[@]}" --show-trace --print-build-logs -v
}

build_host() {
  local repo="$1"
  local platform="$2"
  local host="$3"

  local build_cmd
  if [[ "$platform" == "linux" ]]; then
    build_cmd=(nixos-rebuild build --flake "${repo}#${host}" "${nix_auth_args[@]}" --show-trace --print-build-logs -v)
  else
    build_cmd=(darwin-rebuild build --flake "${repo}#${host}" "${nix_auth_args[@]}" --show-trace --print-build-logs -v)
  fi

  local exit_code=0
  "${build_cmd[@]}" || exit_code=$?

  # Clean up any build symlink created in the repo
  rm -f "${repo}/result"

  return "$exit_code"
}

build_all_impl() {
  local repo="$1"
  local platform="$2"
  local current_host="${3:-}"

  validate_platform "$platform"
  local all_hosts=()
  if [[ "$platform" == "linux" ]]; then
    all_hosts=(JIN FENNEC LULA)
  else
    all_hosts=(EDGE)
  fi

  # Prioritize building current_host first if specified and in the list
  local hosts=()
  if [[ -n "$current_host" ]]; then
    for h in "${all_hosts[@]}"; do
      if [[ "$h" == "$current_host" ]]; then
        hosts+=("$h")
        break
      fi
    done
    for h in "${all_hosts[@]}"; do
      if [[ "$h" != "$current_host" ]]; then
        hosts+=("$h")
      fi
    done
  else
    hosts=("${all_hosts[@]}")
  fi

  build_status="building all ${platform} hosts"
  for host in "${hosts[@]}"; do
    printf '\n--- Building %s (%s) ---\n' "$host" "$platform"
    if build_host "$repo" "$platform" "$host"; then
      host_results+=("${host}: passed")
    else
      host_results+=("${host}: failed")
      build_status="failed on ${host}"
      fail "Build failed for host: ${host}"
    fi
  done
  build_status="all ${platform} hosts passed"
}

switch_current_impl() {
  local repo="$1"
  local hostname="$2"
  local platform="$3"

  switch_status="activating ${hostname}"
  if [[ "$platform" == "linux" ]]; then
    sudo nixos-rebuild switch --flake "${repo}#${hostname}" "${nix_auth_args[@]}" --show-trace --print-build-logs -v
  else
    sudo darwin-rebuild switch --flake "${repo}#${hostname}" "${nix_auth_args[@]}" --show-trace --print-build-logs -v
  fi
  switch_status="activated ${hostname}"
}

publish_public_impl() {
  local repo="$1"

  if commit_all_if_dirty "$repo" "flake.lock: upgrade inputs"; then
    public_status="committed and ready to push"
  else
    public_status="no new files to commit"
  fi

  if ! git -C "$repo" push --verbose; then
    public_status="${public_status}; push failed"
    return 1
  fi
  public_status="pushed"
}

upgrade() {
  local public_repo_arg="$1"
  local private_repo="$2"
  local hostname="$3"
  local platform="$4"

  public_repo="$public_repo_arg"
  validate_platform "$platform"
  is_git_repo "$public_repo" || fail "Public repository is not a Git checkout: $public_repo"
  start_log "upgrade" "$hostname"
  check_common_commands
  check_nix_commands
  require_command sudo
  if [[ "$platform" == "linux" ]]; then
    require_command nixos-rebuild
  else
    require_command darwin-rebuild
  fi
  load_github_token

  # Pre-elevate sudo and maintain keepalive loop during long builds
  printf 'Authenticating sudo for upgrade workflow...\n'
  sudo -v
  ( while true; do sudo -n -v 2>/dev/null; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
  sudo_keepalive_pid=$!

  run_phase "Publish private repository changes" publish_private_impl "$private_repo"
  run_phase "Prepare public repository" prepare_public_impl "$public_repo"
  run_phase "Update flake inputs" update_flake_impl "$public_repo"
  run_phase "Check flake" check_flake_impl "$public_repo"
  run_phase "Build all ${platform} hosts" build_all_impl "$public_repo" "$platform" "$hostname"
  run_phase "Activate ${hostname}" switch_current_impl "$public_repo" "$hostname" "$platform"
  run_phase "Publish public repository" publish_public_impl "$public_repo"
}

publish_public() {
  local public_repo_arg="$1"
  public_repo="$public_repo_arg"
  is_git_repo "$public_repo" || fail "Public repository is not a Git checkout: $public_repo"
  start_log "publish-public"
  check_common_commands
  run_phase "Publish public repository" publish_public_impl "$public_repo"
}

publish_private() {
  local private_repo="$1"
  start_log "publish-private"
  check_common_commands
  run_phase "Publish private repository" publish_private_impl "$private_repo"
}

check_remote_updates_impl() {
  local repo="$1"
  remote_has_changes="no"
  printf 'Fetching origin main...\n'
  if ! git -C "$repo" fetch origin main --verbose; then
    fail "Failed to fetch origin/main. Network or remote error."
  fi
  local local_rev remote_rev
  local_rev="$(git -C "$repo" rev-parse HEAD)"
  remote_rev="$(git -C "$repo" rev-parse origin/main)"
  if [[ "$local_rev" != "$remote_rev" ]]; then
    remote_has_changes="yes"
    printf 'Remote origin/main has new revisions (%s -> %s).\n' "$local_rev" "$remote_rev"
  else
    printf 'Local repository is already at origin/main (%s).\n' "$local_rev"
  fi
}

ff_public_repo_impl() {
  local repo="$1"
  if git_is_dirty "$repo"; then
    fail "Public repository has uncommitted changes. Auto-upgrade staging skipped."
  fi
  if ! git -C "$repo" pull --verbose --ff-only origin main; then
    fail "Could not fast-forward repository to origin/main. Manual sync required."
  fi
  public_status="fast-forwarded"
}

stage_boot_impl() {
  local repo="$1"
  local hostname="$2"
  switch_status="staging ${hostname} for next boot"
  local cmd=()
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    cmd=(sudo nixos-rebuild boot --flake "${repo}#${hostname}" "${nix_auth_args[@]}" --show-trace --print-build-logs -v)
  else
    cmd=(nixos-rebuild boot --flake "${repo}#${hostname}" "${nix_auth_args[@]}" --show-trace --print-build-logs -v)
  fi
  "${cmd[@]}"
  switch_status="staged ${hostname} for next boot"
  staged_status="staged"
}

auto_boot() {
  local public_repo_arg="$1"
  local hostname="$2"

  public_repo="$public_repo_arg"
  current_hostname="$hostname"
  target_platform="linux"
  validate_platform "linux"
  is_git_repo "$public_repo" || fail "Public repository is not a Git checkout: $public_repo"

  start_log "auto-boot" "$hostname"
  check_common_commands
  check_nix_commands
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    require_command sudo
    sudo -v
    ( while true; do sudo -n -v 2>/dev/null; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    sudo_keepalive_pid=$!
  fi
  require_command nixos-rebuild
  load_github_token

  run_phase "Check remote updates" check_remote_updates_impl "$public_repo"
  if [[ "$remote_has_changes" == "no" ]]; then
    printf 'Repository is already up to date with origin/main. No auto-boot update required.\n'
    return 0
  fi

  run_phase "Fast-forward public repository" ff_public_repo_impl "$public_repo"
  run_phase "Check flake" check_flake_impl "$public_repo"
  run_phase "Stage system for next boot" stage_boot_impl "$public_repo" "$hostname"
}

build_all() {
  local public_repo_arg="$1"
  local platform="$2"
  local current_host="${3:-}"
  public_repo="$public_repo_arg"
  validate_platform "$platform"
  is_git_repo "$public_repo" || fail "Public repository is not a Git checkout: $public_repo"
  start_log "build-all" "${current_host:-$platform}"
  check_common_commands
  check_nix_commands
  load_github_token
  if [[ "$platform" == "linux" ]]; then
    require_command nixos-rebuild
  else
    require_command darwin-rebuild
  fi
  run_phase "Build all ${platform} hosts" build_all_impl "$public_repo" "$platform" "$current_host"
}

show_logs() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/infra-nix-config/upgrade"
  local logs
  if [[ ! -d "$state_dir" ]]; then
    printf 'No workflow logs found in %s\n' "$state_dir"
    return 0
  fi
  printf 'Workflow logs in %s:\n' "$state_dir"
  logs=("$state_dir"/*.log)
  if [[ ! -e "${logs[0]}" ]]; then
    printf 'No workflow logs found.\n'
    return 0
  fi
  ls -1t "${logs[@]}" | head -20
}

main() {
  local command="${1:-}"
  case "$command" in
    upgrade)
      [[ "$#" -eq 5 ]] || { usage; return 2; }
      upgrade "$2" "$3" "$4" "$5"
      ;;
    auto-boot)
      [[ "$#" -eq 3 ]] || { usage; return 2; }
      auto_boot "$2" "$3"
      ;;
    publish-public)
      [[ "$#" -eq 2 ]] || { usage; return 2; }
      publish_public "$2"
      ;;
    publish-private)
      [[ "$#" -eq 2 ]] || { usage; return 2; }
      publish_private "$2"
      ;;
    build-all)
      [[ "$#" -ge 3 && "$#" -le 4 ]] || { usage; return 2; }
      build_all "$2" "$3" "${4:-}"
      ;;
    logs)
      [[ "$#" -eq 1 ]] || { usage; return 2; }
      show_logs
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
