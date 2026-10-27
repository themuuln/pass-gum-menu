#!/usr/bin/env bash
# Integration tests for pass-gum-menu — disposable password store only.
#
# Safety: every test exports a fresh mktemp PREFIX. The real password store is
# never read or touched.
#
# Covers:
#   1. cmd_menu_entries listing/sorting over fixture .gpg files.
#   2. cmd_menu_entry_directories output over the same fixtures.
#   3. `menu.bash --help` prints usage (exit 0) without side effects.
#   4. Missing gum fails closed in direct and pass-style sourced entrypoints.
#
# Deps: bash and standard filesystem tools; no pass/gpg/gum required.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

pass_count=0
fail_count=0

pass() { printf 'PASS: %s\n' "$1"; pass_count=$((pass_count + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; fail_count=$((fail_count + 1)); }

# --- 1 & 2: listing/sorting + directories over fixture store ----------------

fixture_store="$(mktemp -d)"
trap 'rm -rf "$fixture_store"; [[ -z "${empty_path:-}" ]] || rm -rf "$empty_path"' EXIT
export PREFIX="$fixture_store"

mkdir -p "$PREFIX/personal" "$PREFIX/work/nested"
printf 'synthetic fixture\n' > "$PREFIX/personal/github.gpg"
touch "$PREFIX/personal/bank.gpg" "$PREFIX/work/email.gpg" "$PREFIX/work/nested/vpn.gpg"
mkdir -p "$PREFIX/.git" "$PREFIX/.extensions"
touch "$PREFIX/.git/ignored.gpg" "$PREFIX/.extensions/ignored.gpg"
touch "$PREFIX/stray.gpg"

# Library mode is explicit; ordinary sourcing by pass must still run the menu.
# shellcheck source=../menu.bash
PASS_GUM_MENU_LIBRARY=1 source "$REPO_ROOT/menu.bash"

entries="$(cmd_menu_entries)"
expected_entries="$(printf 'personal/bank\npersonal/github\nstray\nwork/email\nwork/nested/vpn')"
if [[ "$entries" == "$expected_entries" ]]; then
	pass "cmd_menu_entries lists and sorts .gpg fixtures, pruning .git/.extensions"
else
	fail "cmd_menu_entries mismatch; got: $(printf '%q' "$entries")"
fi

dirs="$(cmd_menu_entry_directories)"
expected_dirs="$(printf 'personal/\nwork/\nwork/nested/')"
if [[ "$dirs" == "$expected_dirs" ]]; then
	pass "cmd_menu_entry_directories emits parent dirs"
else
	fail "cmd_menu_entry_directories mismatch; got: $(printf '%q' "$dirs")"
fi

# A .gpg added after sourcing must appear (no store mutation by the test
# itself beyond its own disposable fixture).
touch "$PREFIX/personal/new.gpg"
if cmd_menu_entries | grep -qx "personal/new"; then
	pass "cmd_menu_entries reflects new fixture entry"
else
	fail "cmd_menu_entries missing newly added fixture entry"
fi
rm "$PREFIX/personal/new.gpg"

before_help="$(cd "$PREFIX" && find . -type f -exec cksum {} \; | sort)"
for flag in --help -h; do
	if bash "$REPO_ROOT/menu.bash" "$flag" >/dev/null; then
		pass "$flag exits successfully"
	else
		fail "$flag exits unsuccessfully"
	fi
done
after_help="$(cd "$PREFIX" && find . -type f -exec cksum {} \; | sort)"
if [[ "$before_help" == "$after_help" ]]; then
	pass "help leaves fixture names and contents unchanged"
else
	fail "help mutated the fixture store"
fi

# --- 4: missing gum fails closed, store untouched -----------------------------

before_snapshot="$(cd "$PREFIX" && find . -type f -exec cksum {} \; | sort)"
empty_path="$(mktemp -d)"
bash_bin="$(command -v bash)"
for mode in direct sourced; do
	set +e
	if [[ "$mode" == direct ]]; then
		missing_gum_out="$(env -i "PATH=$empty_path" "PREFIX=$PREFIX" "$bash_bin" "$REPO_ROOT/menu.bash" 2>&1)"
	else
		missing_gum_out="$(env -i "PATH=$empty_path" "PREFIX=$PREFIX" "$bash_bin" -c 'source "$1"' _ "$REPO_ROOT/menu.bash" 2>&1)"
	fi
	missing_gum_code=$?
	set -e
	if [[ $missing_gum_code -eq 1 ]]; then
		pass "$mode entrypoint rejects missing gum"
	else
		fail "$mode entrypoint: exit=$missing_gum_code output=$missing_gum_out"
	fi
done
rmdir "$empty_path"
empty_path=""
after_snapshot="$(cd "$PREFIX" && find . -type f -exec cksum {} \; | sort)"

if [[ "$before_snapshot" == "$after_snapshot" ]]; then
	pass "missing gum run leaves PREFIX untouched"
else
	fail "PREFIX mutated by missing-gum run"
fi

# --- summary ------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
[[ $fail_count -eq 0 ]]
