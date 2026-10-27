#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# pass menu - Password Store Extension
# Interactive gum-based menu for common password-store workflows.

cmd_menu_usage() {
	cat <<-'EOF'
	Usage: pass menu

	Open an interactive menu to browse, copy, add, generate, edit,
	regenerate, and remove password-store entries.
	EOF
	exit 0
}

cmd_menu_entries() {
	find -L "$PREFIX" -path '*/.git' -prune -o -path '*/.extensions' -prune -o -iname '*.gpg' -print |
		sed -e "s|^${PREFIX}/||" -e 's/\.gpg$//' |
		sort
}

cmd_menu_entry_directories() {
	local entry directory

	while IFS= read -r entry; do
		directory="${entry%/*}"
		while [[ $directory != "$entry" && -n $directory ]]; do
			printf '%s/\n' "$directory"
			[[ $directory == */* ]] || break
			directory="${directory%/*}"
		done
	done < <(cmd_menu_entries) |
		sort -u
}

cmd_menu_pick_entry() {
	local header="${1:-Select an entry}"

	cmd_menu_entries |
		gum filter \
			--header "$header" \
			--placeholder "Type to search..." \
			--height 20 \
			--prompt "Search: " \
			--fuzzy
}

cmd_menu_pause() {
	gum input --placeholder "Press enter to continue" >/dev/null
}

cmd_menu_message() {
	local color="$1"
	shift
	gum style --foreground "$color" "$*" >&2
}

cmd_menu_prompt_length() {
	local length

	while true; do
		if ! length="$(gum input \
			--header "Password length" \
			--value "${GENERATED_LENGTH:-25}" \
			--placeholder "Enter a positive number")"; then
			return 1
		fi

		if [[ $length =~ ^[0-9]+$ && $length -gt 0 ]]; then
			printf '%s\n' "$length"
			return 0
		fi

		cmd_menu_message 1 "Length must be a positive number."
	done
}

cmd_menu_prompt_character_mode() {
	gum choose \
		--header "Password characters" \
		"Include symbols" \
		"Letters and numbers only" \
		"Cancel"
}

cmd_menu_prompt_new_entry() {
	local entry directory_suggestions

	directory_suggestions="$(cmd_menu_entry_directories)"

	while true; do
		if [[ -n $directory_suggestions ]]; then
			if ! entry="$(printf '%s\n' "$directory_suggestions" |
				gum filter \
					--header "Choose a folder, or type a full new path" \
					--placeholder "For example personal/github" \
					--height 15 \
					--prompt "Path: " \
					--fuzzy \
					--no-strict)"; then
				return 1
			fi

			if [[ $entry == */ ]]; then
				if ! entry="$(gum input \
					--header "New password in ${entry%/}" \
					--value "$entry" \
					--placeholder "Complete the entry path")"; then
					return 1
				fi
			fi
		elif ! entry="$(gum input \
			--header "New password" \
			--placeholder "Entry path, for example personal/github")"; then
			return 1
		fi

		[[ -z $entry ]] && return 1

		if [[ -e "$PREFIX/$entry.gpg" || -d "$PREFIX/$entry" ]]; then
			cmd_menu_message 1 "An entry or folder named '$entry' already exists."
			continue
		fi

		printf '%s\n' "$entry"
		return 0
	done
}

cmd_menu_insert_manual() {
	local entry password password_again

	entry="$(cmd_menu_prompt_new_entry)" || return

	while true; do
		if ! password="$(gum input \
			--password \
			--header "Password for $entry" \
			--placeholder "Enter password")"; then
			return
		fi

		if [[ -z $password ]]; then
			cmd_menu_message 1 "Password cannot be empty."
			continue
		fi

		if ! password_again="$(gum input \
			--password \
			--header "Confirm password for $entry" \
			--placeholder "Retype password")"; then
			return
		fi

		if [[ $password != "$password_again" ]]; then
			cmd_menu_message 1 "Passwords do not match. Try again."
			continue
		fi

		break
	done

	printf '%s\n' "$password" | cmd_insert --echo "$entry"
	if [[ -f "$PREFIX/$entry.gpg" ]]; then
		cmd_menu_message 2 "Saved $entry."
		if gum confirm "Copy the new password now?"; then
			cmd_show --clip "$entry"
		fi
	else
		cmd_menu_message 1 "Could not save $entry."
		cmd_menu_pause
	fi

	password=""
	password_again=""
}

cmd_menu_generate_new() {
	local entry length character_mode
	local -a generate_options=(--clip)

	entry="$(cmd_menu_prompt_new_entry)" || return
	length="$(cmd_menu_prompt_length)" || return
	character_mode="$(cmd_menu_prompt_character_mode)" || return

	case "$character_mode" in
	"Letters and numbers only")
		generate_options+=(--no-symbols)
		;;
	"Cancel" | "")
		return
		;;
	esac

	if cmd_generate "${generate_options[@]}" "$entry" "$length"; then
		cmd_menu_message 2 "Generated $entry and copied it to the clipboard."
	else
		cmd_menu_message 1 "Could not generate $entry."
		cmd_menu_pause
	fi
}

cmd_menu_regenerate() {
	local entry="$1"
	local length character_mode
	local -a generate_options=(--in-place --clip)

	length="$(cmd_menu_prompt_length)" || return
	character_mode="$(cmd_menu_prompt_character_mode)" || return

	case "$character_mode" in
	"Letters and numbers only")
		generate_options+=(--no-symbols)
		;;
	"Cancel" | "")
		return
		;;
	esac

	if gum confirm "Replace the password for $entry and keep its other lines?"; then
		cmd_generate "${generate_options[@]}" "$entry" "$length"
	fi
}

cmd_menu_has_otp() {
	[[ -x "${EXTENSIONS:-}/otp.bash" ||
		(-n ${SYSTEM_EXTENSION_DIR:-} && -x "$SYSTEM_EXTENSION_DIR/otp.bash") ]]
}

cmd_menu_entry_actions() {
	local entry="$1"
	local action
	local -a actions=("Copy password")

	if cmd_menu_has_otp; then
		actions+=("Copy OTP code")
	fi

	actions+=(
		"Show entry"
		"Edit entry"
		"Regenerate password"
		"Delete entry"
		"Back"
	)

	while true; do
		if ! action="$(gum choose --header "$entry" "${actions[@]}")"; then
			return
		fi

		case "$action" in
		"Copy password")
			cmd_show --clip "$entry"
			return
			;;
		"Copy OTP code")
			if pass otp --clip "$entry"; then
				return
			fi
			cmd_menu_message 1 "This entry does not contain an OTP secret."
			cmd_menu_pause
			;;
		"Show entry")
			cmd_show "$entry"
			cmd_menu_pause
			;;
		"Edit entry")
			cmd_edit "$entry"
			return
			;;
		"Regenerate password")
			cmd_menu_regenerate "$entry"
			return
			;;
		"Delete entry")
			if gum confirm "Delete $entry? This cannot be undone."; then
				cmd_delete --force "$entry"
				return
			fi
			;;
		"Back" | "")
			return
			;;
		esac
	done
}

cmd_menu_browse() {
	local entry

	entry="$(cmd_menu_pick_entry "Browse passwords")" || return
	[[ -z $entry ]] && return
	cmd_menu_entry_actions "$entry"
}

if ! declare -F die >/dev/null 2>&1; then
	die() {
		printf 'Error: %s\n' "$*" >&2
		exit 1
	}
fi

cmd_menu() {
	local action

	command -v gum >/dev/null 2>&1 ||
		die "pass menu requires Gum. Install it with 'brew install gum' or see https://github.com/charmbracelet/gum#installation"

	while true; do
		if ! action="$(gum choose \
			--header "Password Store" \
			"Browse passwords" \
			"Add password" \
			"Generate password" \
			"Quit")"; then
			return
		fi

		case "$action" in
		"Browse passwords")
			cmd_menu_browse
			;;
		"Add password")
			cmd_menu_insert_manual
			;;
		"Generate password")
			cmd_menu_generate_new
			;;
		"Quit" | "")
			return
			;;
		esac
	done
}

if [[ "${PASS_GUM_MENU_LIBRARY:-0}" != "1" ]]; then
	[[ ${1:-} == "help" || ${1:-} == "--help" || ${1:-} == "-h" ]] && cmd_menu_usage
	cmd_menu
fi
