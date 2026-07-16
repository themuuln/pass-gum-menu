#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

force=0
if [[ ${1:-} == "--force" ]]; then
	force=1
	shift
fi

if [[ $# -ne 0 ]]; then
	printf 'Usage: %s [--force]\n' "${0##*/}" >&2
	exit 2
fi

command -v pass >/dev/null 2>&1 || {
	printf 'Error: pass is not installed or not on PATH.\n' >&2
	exit 1
}

command -v gum >/dev/null 2>&1 || {
	printf 'Error: Gum is not installed. See https://github.com/charmbracelet/gum#installation\n' >&2
	exit 1
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_file="$script_dir/menu.bash"
password_store_dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
extensions_dir="${PASSWORD_STORE_EXTENSIONS_DIR:-$password_store_dir/.extensions}"
target_file="$extensions_dir/menu.bash"

if [[ -e $target_file && $force -ne 1 ]]; then
	if cmp -s "$source_file" "$target_file"; then
		printf 'pass-gum-menu is already installed at %s\n' "$target_file"
		exit 0
	fi

	printf 'Error: %s already exists. Re-run with --force to replace it.\n' "$target_file" >&2
	exit 1
fi

mkdir -p "$extensions_dir"
install -m 0755 "$source_file" "$target_file"

printf 'Installed pass-gum-menu at %s\n\n' "$target_file"
printf 'Enable pass extensions in your shell configuration:\n'
printf '  export PASSWORD_STORE_ENABLE_EXTENSIONS=true\n\n'
printf 'Optional shortcut:\n'
printf "  alias p='pass menu'\n\n"
printf 'Then restart your shell and run: pass menu\n'
