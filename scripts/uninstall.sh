#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck disable=SC1091
# shellcheck source=../lib/codex-installer.sh
. "${SCRIPT_DIR}/../lib/codex-installer.sh"

print_help() {
  cat <<'EOF'
Remove a Codex installation created by this repository.

Usage:
  ./scripts/uninstall.sh [options]

Options:
  --install-dir DIR   Remove codex from DIR instead of the default location.
  --purge-config      Also remove ${CODEX_HOME:-$HOME/.codex}.
  --help, -h          Show this help text.
EOF
}

main() {
    local install_dir="${CODEX_INSTALL_DIR:-}"
    local purge_config=0
    local codex_path codex_home
    
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --install-dir)
                [ "$#" -ge 2 ] || die "--install-dir requires a value."
                install_dir="$2"
                shift 2
            ;;
            --purge-config)
                purge_config=1
                shift
            ;;
            --help | -h)
                print_help
                exit 0
            ;;
            *)
                die "Unknown argument: $1"
            ;;
        esac
    done
    
    if [ -z "$install_dir" ]; then
        install_dir="$(default_install_dir)"
    fi
    
    if ! codex_path="$(resolve_codex_binary "$install_dir")"; then
        die "Could not find a codex binary to remove."
    fi
    
    remove_file "$codex_path"
    log_info "Removed ${codex_path}."
    
    if [ "$purge_config" != "1" ]; then
        return 0
    fi
    
    codex_home="${CODEX_HOME:-${HOME}/.codex}"
    if [ ! -d "$codex_home" ]; then
        log_info "Codex home ${codex_home} does not exist, so nothing else was removed."
        return 0
    fi
    
    rm -rf "$codex_home"
    log_info "Removed ${codex_home}."
}

main "$@"
