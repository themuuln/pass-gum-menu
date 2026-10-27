# pass-gum-menu

An interactive [Gum](https://github.com/charmbracelet/gum)-based terminal menu for [`pass`](https://www.passwordstore.org/), the standard Unix password manager.

It keeps `pass` as the source of truth: encryption, decryption, clipboard handling, editing, and Git integration still run through the commands provided by `pass`.

## Features

- Fuzzy-search existing password entries
- Copy a password using the normal `pass` clipboard timeout
- Add a password with masked input and confirmation
- Generate passwords with a configurable length and character set
- Suggest existing folders while entering a new password path
- Show, edit, regenerate, and delete entries
- Preserve metadata below the first line when regenerating a password
- Show an OTP copy action when the optional [`pass-otp`](https://github.com/tadfisher/pass-otp) extension is installed

## Requirements

- Bash
- [`pass`](https://www.passwordstore.org/)
- [`gum`](https://github.com/charmbracelet/gum)
- An initialized password store with a working GPG recipient

On macOS with Homebrew:

```sh
brew install pass gum
```

For other Gum installation methods, see the [official Gum installation guide](https://github.com/charmbracelet/gum#installation).

## Install

```sh
git clone https://github.com/themuuln/pass-gum-menu.git
cd pass-gum-menu
./install.sh
```

The installer copies `menu.bash` into:

1. `$PASSWORD_STORE_EXTENSIONS_DIR`, when set; otherwise
2. `${PASSWORD_STORE_DIR:-$HOME/.password-store}/.extensions`

It will not replace an existing `menu.bash` unless you explicitly run:

```sh
./install.sh --force
```

Enable user extensions in your shell configuration (`~/.zshrc`, `~/.bashrc`, or equivalent):

```sh
export PASSWORD_STORE_ENABLE_EXTENSIONS=true
```

Optionally add a short alias:

```sh
alias p='pass menu'
```

Restart the shell, then run:

```sh
pass menu
```

## Update

From the cloned repository:

```sh
git pull --ff-only
./install.sh --force
```

## Manual installation

```sh
mkdir -p "${PASSWORD_STORE_DIR:-$HOME/.password-store}/.extensions"
install -m 0755 menu.bash "${PASSWORD_STORE_DIR:-$HOME/.password-store}/.extensions/menu.bash"
```

Then export `PASSWORD_STORE_ENABLE_EXTENSIONS=true` as shown above.

## Security model

- This project does not contain or upload password-store data.
- Passwords entered in the menu are masked by Gum and passed directly to `pass` for GPG encryption.
- Clipboard operations use `pass` itself, including its configured clipboard-clear timeout.
- The installer only copies the extension file. It does not modify shell configuration, GPG configuration, or password entries.
- There is no telemetry or network access in the extension.

As with any password-manager extension, review `menu.bash` before installing it.

## Development

Validate changes with:

```sh
bash -n menu.bash install.sh
shellcheck menu.bash install.sh
```

For behavioral checks, use a temporary `PASSWORD_STORE_DIR`; never test destructive actions against a real password store.

### Integration tests

```sh
bash tests/integration.sh
```

CI (`.github/workflows/ci.yml`) checks syntax and runs the suite against a disposable `PREFIX`. Tests load functions with explicit `PASS_GUM_MENU_LIBRARY=1`; normal sourcing by pass still runs the menu.

- `cmd_menu_entries` listing/sorting over fixture `.gpg` files (pruning `.git`/`.extensions`);
- `cmd_menu_entry_directories` parent-directory output;
- `--help` / `-h` exit successfully without changing fixture names or contents;
- direct and pass-style sourced entrypoints reject missing `gum` with exit 1; fixture names and checksums remain unchanged.

The real password store is never read or touched: every run exports a fresh `mktemp -d` `PREFIX`, and the missing-gum subprocess receives only that temp `PREFIX`. A local `die` fallback preserves the fail-closed missing-gum behavior when `menu.bash` runs outside pass (where the `pass` framework normally provides `die`); under `pass` the framework's `die` still wins.
## License

GPL-2.0-only. See [LICENSE](LICENSE).
