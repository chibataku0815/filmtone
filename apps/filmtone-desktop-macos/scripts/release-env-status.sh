#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/load-release-env.sh
. "${script_dir}/load-release-env.sh"

is_set() {
  local name="$1"
  [ "${!name+x}" = "x" ] && [ -n "${!name}" ]
}

truthy() {
  case "${!1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

status_line() {
  local name="$1"
  if is_set "${name}"; then
    printf '%s=set\n' "${name}"
  else
    printf '%s=unset\n' "${name}"
  fi
}

read_marketing_version() {
  grep -m1 'MARKETING_VERSION' "${FILMTONE_MAC_APP_ROOT}/FilmtoneDesktop.xcodeproj/project.pbxproj" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' \
    | tr -d ' '
}

read_build_number() {
  grep -m1 'CURRENT_PROJECT_VERSION' "${FILMTONE_MAC_APP_ROOT}/FilmtoneDesktop.xcodeproj/project.pbxproj" \
    | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);.*/\1/' \
    | tr -d ' '
}

resolve_candidate_path() {
  local value="$1"
  if [[ "${value}" = /* ]]; then
    printf '%s\n' "${value}"
    return
  fi

  local app_path="${FILMTONE_MAC_APP_ROOT}/${value}"
  if [ -e "${app_path}" ]; then
    printf '%s\n' "${app_path}"
    return
  fi

  if [ -n "${FILMTONE_IOS_RELEASE_ENV_ROOT:-}" ]; then
    local ios_path="${FILMTONE_IOS_RELEASE_ENV_ROOT}/${value}"
    if [ -e "${ios_path}" ]; then
      printf '%s\n' "${ios_path}"
      return
    fi
  fi

  printf '%s\n' "${FILMTONE_REPO_ROOT}/${value}"
}

default_pkg_path() {
  printf '%s/build/app-store/%s/export/Filmtone.pkg\n' \
    "${FILMTONE_MAC_APP_ROOT}" \
    "$(read_marketing_version)"
}

has_asc_key_material() {
  is_set "ASC_KEY_CONTENT" || is_set "ASC_KEY_PATH"
}

has_asc_key() {
  is_set "ASC_KEY_ID" && is_set "ASC_ISSUER_ID" && has_asc_key_material
}

pkg_path_exists() {
  local candidate
  if is_set "PKG_PATH"; then
    candidate="$(resolve_candidate_path "${PKG_PATH}")"
  else
    candidate="$(default_pkg_path)"
  fi
  [ -f "${candidate}" ]
}

has_pkg_or_build() {
  pkg_path_exists || truthy "BUILD_MAS_PKG"
}

missing_for() {
  local missing=()

  case "$1" in
    metadata)
      has_asc_key || missing+=("ASC key")
      is_set "REVIEW_PHONE" || missing+=("REVIEW_PHONE")
      ;;
    upload)
      has_asc_key || missing+=("ASC key")
      pkg_path_exists || missing+=("PKG_PATH or default MAS pkg")
      ;;
    release)
      has_asc_key || missing+=("ASC key")
      has_pkg_or_build || missing+=("PKG_PATH/default MAS pkg or BUILD_MAS_PKG=1")
      is_set "REVIEW_PHONE" || missing+=("REVIEW_PHONE")
      ;;
    submit-review)
      has_asc_key || missing+=("ASC key")
      is_set "REVIEW_PHONE" || missing+=("REVIEW_PHONE")
      truthy "SUBMIT_FOR_REVIEW" || missing+=("SUBMIT_FOR_REVIEW=1")
      truthy "CONFIRM_METADATA_READY" || missing+=("CONFIRM_METADATA_READY=1")
      ;;
    status)
      has_asc_key || missing+=("ASC key")
      is_set "DELIVERY_ID" || missing+=("DELIVERY_ID")
      ;;
  esac

  if [ "${#missing[@]}" -eq 0 ]; then
    printf 'ready'
  else
    local IFS=', '
    printf 'missing %s' "${missing[*]}"
  fi
}

printf 'Filmtone macOS App Store release env status (values hidden)\n'
printf 'FILMTONE_MAC_APP_ROOT=%s\n' "${FILMTONE_MAC_APP_ROOT}"
printf 'APP_VERSION(default)=%s\n' "$(read_marketing_version)"
printf 'BUILD_NUMBER(default)=%s\n' "$(read_build_number)"
status_line "ASC_KEY_ID"
status_line "ASC_ISSUER_ID"
status_line "ASC_KEY_CONTENT"
status_line "ASC_KEY_PATH"

if is_set "ASC_KEY_PATH"; then
  asc_key_path="$(resolve_candidate_path "${ASC_KEY_PATH}")"
  if [ -f "${asc_key_path}" ]; then
    printf 'ASC_KEY_PATH_EXISTS=yes\n'
  else
    printf 'ASC_KEY_PATH_EXISTS=no\n'
  fi
  unset asc_key_path
fi

status_line "REVIEW_PHONE"
status_line "PKG_PATH"
if pkg_path_exists; then
  printf 'PKG_PATH_EXISTS=yes\n'
else
  printf 'PKG_PATH_EXISTS=no\n'
fi
status_line "DELIVERY_ID"
status_line "SUBMIT_FOR_REVIEW"
status_line "CONFIRM_METADATA_READY"
status_line "AUTOMATIC_RELEASE"
status_line "BUILD_MAS_PKG"

printf '\nLane readiness (values hidden)\n'
printf 'release:macos-appstore:metadata=%s\n' "$(missing_for metadata)"
printf 'release:macos-appstore:upload=%s\n' "$(missing_for upload)"
printf 'release:macos-appstore:release=%s\n' "$(missing_for release)"
printf 'release:macos-appstore:submit-review=%s\n' "$(missing_for submit-review)"
printf 'release:macos-appstore:status=%s\n' "$(missing_for status)"
