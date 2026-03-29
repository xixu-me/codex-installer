#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck disable=SC1091
# shellcheck source=../lib/codex-installer.sh
. "${SCRIPT_DIR}/../lib/codex-installer.sh"

assert_eq() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    
    if [ "$actual" != "$expected" ]; then
        printf 'Assertion failed: %s\nExpected: %s\nActual:   %s\n' "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

assert_file_content_eq() {
    local path="$1"
    local expected="$2"
    local message="$3"
    local actual

    actual="$(cat "$path")"
    assert_eq "$actual" "$expected" "$message"
}

main() {
    local tmp_file temp_root real_tar fake_tar_bin fake_install_bin
    local archive_input_dir archive_path install_dir source_binary extracted_path
    local installed_path old_path
    
    assert_eq "$(normalize_arch arm64)" "aarch64" "arm64 normalizes to aarch64"
    assert_eq "$(normalize_arch amd64)" "x86_64" "amd64 normalizes to x86_64"
    assert_eq "$(normalize_release_ref latest)" "latest" "latest release remains latest"
    assert_eq "$(normalize_release_ref 0.115.0)" "rust-v0.115.0" "bare version is normalized"
    assert_eq "$(normalize_release_ref v0.115.0)" "rust-v0.115.0" "v-prefixed version is normalized"
    assert_eq "$(normalize_release_ref rust-v0.115.0)" "rust-v0.115.0" "full tag is preserved"
    
    assert_eq \
    "$(codex_release_asset_for darwin aarch64)" \
    "codex-aarch64-apple-darwin.tar.gz" \
    "darwin arm64 asset selection"
    assert_eq \
    "$(codex_release_asset_for darwin x86_64)" \
    "codex-x86_64-apple-darwin.tar.gz" \
    "darwin x86_64 asset selection"
    assert_eq \
    "$(codex_release_asset_for linux aarch64)" \
    "codex-aarch64-unknown-linux-musl.tar.gz" \
    "linux arm64 asset selection"
    assert_eq \
    "$(codex_release_asset_for linux x86_64)" \
    "codex-x86_64-unknown-linux-musl.tar.gz" \
    "linux x86_64 asset selection"
    assert_eq \
    "$(normalize_sha256 'sha256:abcdef')" \
    "abcdef" \
    "sha256 prefix is stripped"
    
    tmp_file="$(mktemp)"
    trap 'rm -f -- "${tmp_file:-}"' EXIT
    printf 'abc' >"$tmp_file"
    assert_eq \
    "$(sha256_file "$tmp_file")" \
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" \
    "sha256_file extracts the digest without awk"

    temp_root="$(mktemp -d)"
    real_tar="$(command -v tar)"
    trap 'rm -f -- "${tmp_file:-}"; rm -rf -- "${temp_root:-}"' EXIT

    archive_input_dir="${temp_root}/archive-input"
    archive_path="${temp_root}/codex.tar.gz"
    mkdir -p "$archive_input_dir"
    printf 'codex-binary' >"${archive_input_dir}/codex-x86_64-unknown-linux-musl"
    tar -czf "$archive_path" -C "$archive_input_dir" codex-x86_64-unknown-linux-musl

    fake_tar_bin="${temp_root}/fake-tar-bin"
    mkdir -p "$fake_tar_bin"
    cat >"${fake_tar_bin}/tar" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "-tzf" ]; then
    exec "$real_tar" "\$@"
fi

if [ "\$1" = "-xzf" ]; then
    printf 'simulated tar extraction failure\n' >&2
    exit 1
fi

exec "$real_tar" "\$@"
EOF
    chmod +x "${fake_tar_bin}/tar"

    old_path="$PATH"
    PATH="${fake_tar_bin}:$PATH"
    if extracted_path="$(extract_archive_binary "$archive_path" "${temp_root}/extract-output")"; then
        printf 'Assertion failed: extract_archive_binary should fail when tar extraction fails\n' >&2
        exit 1
    fi
    printf '%s' "${extracted_path:-}" >/dev/null
    PATH="$old_path"

    install_dir="${temp_root}/install-dir"
    mkdir -p "$install_dir"
    printf 'existing-binary' >"${install_dir}/codex"
    source_binary="${temp_root}/replacement-codex"
    printf 'replacement-binary' >"$source_binary"
    chmod +x "$source_binary"

    fake_install_bin="${temp_root}/fake-install-bin"
    mkdir -p "$fake_install_bin"
    cat >"${fake_install_bin}/install" <<EOF
#!/usr/bin/env bash
destination="\${!#}"
printf 'partial-binary' >"\$destination"
exit 1
EOF
    chmod +x "${fake_install_bin}/install"

    PATH="${fake_install_bin}:$old_path"
    if installed_path="$(install_binary_to_dir "$source_binary" "$install_dir")"; then
        printf 'Assertion failed: install_binary_to_dir should fail when install exits non-zero\n' >&2
        exit 1
    fi
    printf '%s' "${installed_path:-}" >/dev/null
    PATH="$old_path"

    assert_file_content_eq \
    "${install_dir}/codex" \
    "existing-binary" \
    "failed install keeps the previous codex binary intact"
    
    printf 'Smoke tests passed.\n'
}

main "$@"
