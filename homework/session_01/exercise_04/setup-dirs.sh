#!/usr/bin/env bash
#
# QuickBite Exercise 04: directory ownership and permissions.
#
# Run inside the Ubuntu lab container as root.
#
set -Eeuo pipefail

trap 'rc=$?; printf "[FAIL] command failed at line %s (exit %s)\n" "$LINENO" "$rc" >&2' ERR

readonly QB_USER="quickbite"
readonly QB_GROUP="quickbite"
readonly BASE_DIR="/opt/quickbite"
readonly SERVICE_DIR="/opt/quickbite/user-service"
readonly BASE_MODE="750"

log() { printf '[INFO] %s\n' "$*"; }
ok()  { printf '[ OK ] %s\n' "$*"; }
err() { printf '[FAIL] %s\n' "$*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "this script must run as root inside the Ubuntu container"
    exit 1
  fi
}

require_account() {
  if ! getent group "$QB_GROUP" >/dev/null 2>&1; then
    err "group '$QB_GROUP' does not exist; run initial-script.sh first"
    exit 1
  fi
  if ! getent passwd "$QB_USER" >/dev/null 2>&1; then
    err "user '$QB_USER' does not exist; run initial-script.sh first"
    exit 1
  fi
  ok "user and group '$QB_USER' exist"
}

create_directories() {
  log "Creating $SERVICE_DIR if missing"
  mkdir -p "$SERVICE_DIR"
  ok "directory structure exists"
}

apply_ownership() {
  log "Applying recursive ownership $QB_USER:$QB_GROUP to $BASE_DIR"
  chown -R "$QB_USER:$QB_GROUP" "$BASE_DIR"
  ok "ownership applied"
}

apply_permissions() {
  log "Setting mode $BASE_MODE on $BASE_DIR (not recursive)"
  chmod "$BASE_MODE" "$BASE_DIR"
  ok "mode $BASE_MODE applied"
}

verify_state() {
  local base_mode base_owner base_group service_owner service_group bad_entry

  [[ -d "$BASE_DIR" ]] || { err "$BASE_DIR is missing"; exit 1; }
  [[ -d "$SERVICE_DIR" ]] || { err "$SERVICE_DIR is missing"; exit 1; }

  base_mode="$(stat -c '%a' "$BASE_DIR")"
  base_owner="$(stat -c '%U' "$BASE_DIR")"
  base_group="$(stat -c '%G' "$BASE_DIR")"
  service_owner="$(stat -c '%U' "$SERVICE_DIR")"
  service_group="$(stat -c '%G' "$SERVICE_DIR")"

  [[ "$base_mode" == "$BASE_MODE" ]] || { err "$BASE_DIR mode is $base_mode, expected $BASE_MODE"; exit 1; }
  [[ "$base_owner" == "$QB_USER" ]] || { err "$BASE_DIR owner is $base_owner, expected $QB_USER"; exit 1; }
  [[ "$base_group" == "$QB_GROUP" ]] || { err "$BASE_DIR group is $base_group, expected $QB_GROUP"; exit 1; }
  [[ "$service_owner" == "$QB_USER" ]] || { err "$SERVICE_DIR owner is $service_owner, expected $QB_USER"; exit 1; }
  [[ "$service_group" == "$QB_GROUP" ]] || { err "$SERVICE_DIR group is $service_group, expected $QB_GROUP"; exit 1; }

  bad_entry="$(find "$BASE_DIR" \( ! -user "$QB_USER" -o ! -group "$QB_GROUP" \) -print -quit)"
  [[ -z "$bad_entry" ]] || { err "entry has wrong ownership: $bad_entry"; exit 1; }

  ok "$BASE_DIR is $base_mode $base_owner:$base_group"
  ok "$SERVICE_DIR is $service_owner:$service_group"
}

main() {
  require_root
  require_account
  create_directories
  apply_ownership
  apply_permissions
  verify_state

  log "Final state"
  stat -c '%A %a %U %G %n' "$BASE_DIR"
  stat -c '%U %G %n' "$SERVICE_DIR"
  ok "QuickBite directory setup completed successfully"
}

main "$@"
