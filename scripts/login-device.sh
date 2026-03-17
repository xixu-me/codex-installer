#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck disable=SC1091
# shellcheck source=../lib/codex-installer.sh
. "${SCRIPT_DIR}/../lib/codex-installer.sh"

main() {
    local install_dir="${CODEX_INSTALL_DIR:-}"
    local codex_path
    
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --install-dir)
                [ "$#" -ge 2 ] || die "--install-dir requires a value."
                install_dir="$2"
                shift 2
            ;;
            --help | -h)
        cat <<'EOF'
Run the Codex ChatGPT login flow using device code.

Usage:
  ./scripts/login-device.sh [--install-dir DIR]
EOF
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
        die "Could not find codex. Run ./install.sh first or add codex to PATH."
    fi
    
    login_with_device_code "$codex_path"
}

main "$@"
