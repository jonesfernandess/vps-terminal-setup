# setup-vps

Setup script that installs and configures a modern terminal environment on any OS.

## What it installs

- **[zsh](https://www.zsh.org/)** — shell (if not already present)
- **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)** — suggests commands as you type (accept with right arrow)
- **[zsh-completions](https://github.com/zsh-users/zsh-completions)** — tab completion for common tools
- **[starship](https://starship.rs/)** — minimal, fast, cross-shell prompt
- **[zellij](https://zellij.dev/)** — terminal multiplexer with Catppuccin Mocha theme

## What it configures

- `~/.zshrc` with Starship, autosuggestions, and completions
- `~/.config/starship.toml` from `starship/starship.toml`
- `~/.config/zellij/config.kdl` from `zellij/config.kdl`

## Supported platforms

| OS | Package manager |
|----|----------------|
| macOS | Homebrew |
| Ubuntu/Debian | apt |
| Fedora/RHEL | dnf |
| Arch | pacman |
| openSUSE | zypper |
| Alpine | apk |
| WSL | same as Linux |
| Windows (native) | not supported — use WSL |

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/keysijones/setup-vps/main/setup.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/keysijones/setup-vps.git
cd setup-vps
chmod +x setup.sh
./setup.sh
```

## After install

```bash
zellij                  # start a session
zellij --layout dev     # start with dev layout (3 panes)
```
