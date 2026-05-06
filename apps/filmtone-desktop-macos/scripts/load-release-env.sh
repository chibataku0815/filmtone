#!/usr/bin/env bash
# Source this file from macOS release entrypoints. It loads app-local release
# env files and, when present, the iOS release env root because both products
# use the same App Store Connect API key material.

filmtone_release_restore_nounset=0
case "$-" in
  *u*)
    filmtone_release_restore_nounset=1
    set +u
    ;;
esac

filmtone_release_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FILMTONE_MAC_APP_ROOT="$(cd "${filmtone_release_script_dir}/.." && pwd)"
export FILMTONE_REPO_ROOT="$(cd "${FILMTONE_MAC_APP_ROOT}/../.." && pwd)"

filmtone_release_ios_env_root="${FILMTONE_IOS_RELEASE_ENV_ROOT:-${FILMTONE_REPO_ROOT}/apps/capacitor-film-lab-ios}"

filmtone_release_env_files=(
  "${FILMTONE_MAC_APP_ROOT}/.env"
  "${FILMTONE_MAC_APP_ROOT}/.env.local"
  "${FILMTONE_MAC_APP_ROOT}/fastlane/.env"
  "${FILMTONE_MAC_APP_ROOT}/fastlane/.env.local"
)

if [ -d "${filmtone_release_ios_env_root}" ]; then
  export FILMTONE_IOS_RELEASE_ENV_ROOT="${filmtone_release_ios_env_root}"
  filmtone_release_env_files+=(
    "${filmtone_release_ios_env_root}/.env"
    "${filmtone_release_ios_env_root}/.env.local"
    "${filmtone_release_ios_env_root}/fastlane/.env"
    "${filmtone_release_ios_env_root}/fastlane/.env.local"
  )
fi

if [ -n "${FILMTONE_RELEASE_ENV_FILE:-}" ]; then
  if [[ "${FILMTONE_RELEASE_ENV_FILE}" = /* ]]; then
    filmtone_release_env_files+=("${FILMTONE_RELEASE_ENV_FILE}")
  else
    filmtone_release_env_files+=("${FILMTONE_MAC_APP_ROOT}/${FILMTONE_RELEASE_ENV_FILE}")
  fi
fi

filmtone_release_env_keys=()
for filmtone_release_env_file in "${filmtone_release_env_files[@]}"; do
  [ -f "${filmtone_release_env_file}" ] || continue
  while IFS= read -r filmtone_release_key; do
    case " ${filmtone_release_env_keys[*]} " in
      *" ${filmtone_release_key} "*) ;;
      *) filmtone_release_env_keys+=("${filmtone_release_key}") ;;
    esac
  done < <(
    awk '
      /^[[:space:]]*#/ { next }
      match($0, /^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) {
        line = substr($0, RSTART, RLENGTH)
        sub(/^[[:space:]]*export[[:space:]]+/, "", line)
        sub(/[[:space:]]*=.*$/, "", line)
        print line
      }
    ' "${filmtone_release_env_file}"
  )
done

filmtone_release_original_decls=()
for filmtone_release_key in "${filmtone_release_env_keys[@]}"; do
  if [ "${!filmtone_release_key+x}" = "x" ]; then
    filmtone_release_original_decls+=("$(declare -p "${filmtone_release_key}")")
  fi
done

for filmtone_release_env_file in "${filmtone_release_env_files[@]}"; do
  [ -f "${filmtone_release_env_file}" ] || continue
  set -a
  # shellcheck disable=SC1090
  . "${filmtone_release_env_file}"
  set +a
done

for filmtone_release_decl in "${filmtone_release_original_decls[@]}"; do
  eval "${filmtone_release_decl}"
done

if [ "${filmtone_release_restore_nounset}" = "1" ]; then
  set -u
fi

unset filmtone_release_decl
unset filmtone_release_env_file
unset filmtone_release_env_files
unset filmtone_release_key
unset filmtone_release_env_keys
unset filmtone_release_original_decls
unset filmtone_release_restore_nounset
unset filmtone_release_script_dir
unset filmtone_release_ios_env_root
