#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/load-release-env.sh
. "${script_dir}/load-release-env.sh"

is_set() {
  local name="$1"
  [ "${!name+x}" = "x" ] && [ -n "${!name}" ]
}

status_line() {
  local name="$1"
  if is_set "${name}"; then
    printf '%s=set\n' "${name}"
  else
    printf '%s=unset\n' "${name}"
  fi
}

has_asc_key_material() {
  is_set "ASC_KEY_CONTENT" || is_set "ASC_KEY_PATH"
}

has_asc_key() {
  is_set "ASC_KEY_ID" && is_set "ASC_ISSUER_ID" && has_asc_key_material
}

missing_for() {
  local missing=()

  case "$1" in
    archive)
      has_asc_key || missing+=("ASC key for headless signing")
      ;;
    metadata)
      has_asc_key || missing+=("ASC key")
      is_set "REVIEW_PHONE" || missing+=("REVIEW_PHONE")
      ;;
    beta)
      has_asc_key || missing+=("ASC key")
      is_set "IPA_PATH" || missing+=("IPA_PATH")
      ;;
    appstore)
      has_asc_key || missing+=("ASC key")
      is_set "IPA_PATH" || missing+=("IPA_PATH")
      is_set "REVIEW_PHONE" || missing+=("REVIEW_PHONE")
      ;;
    submit-review)
      has_asc_key || missing+=("ASC key")
      is_set "APP_VERSION" || missing+=("APP_VERSION")
      is_set "BUILD_NUMBER" || missing+=("BUILD_NUMBER")
      is_set "REVIEW_PHONE" || missing+=("REVIEW_PHONE")
      ;;
  esac

  if [ "${#missing[@]}" -eq 0 ]; then
    printf 'ready'
  else
    local IFS=', '
    printf 'missing %s' "${missing[*]}"
  fi
}

printf 'Filmtone iOS release env status (values hidden)\n'
status_line "ASC_KEY_ID"
status_line "ASC_ISSUER_ID"
status_line "ASC_KEY_CONTENT"
status_line "ASC_KEY_PATH"

if is_set "ASC_KEY_PATH"; then
  asc_key_path="${ASC_KEY_PATH}"
  if [[ "${asc_key_path}" != /* ]]; then
    asc_key_path="${FILMTONE_IOS_APP_ROOT}/${asc_key_path}"
  fi

  if [ -f "${asc_key_path}" ]; then
    printf 'ASC_KEY_PATH_EXISTS=yes\n'
  else
    printf 'ASC_KEY_PATH_EXISTS=no\n'
  fi
  unset asc_key_path
fi

status_line "REVIEW_PHONE"
status_line "IPA_PATH"
status_line "APP_VERSION"
status_line "BUILD_NUMBER"
status_line "SNAPSHOT_BASE_LOCALE"

printf '\nLane readiness (values hidden)\n'
printf 'release:archive=%s\n' "$(missing_for archive)"
printf 'release:metadata=%s\n' "$(missing_for metadata)"
printf 'release:beta=%s\n' "$(missing_for beta)"
printf 'release:appstore=%s\n' "$(missing_for appstore)"
printf 'release:submit-review=%s\n' "$(missing_for submit-review)"
