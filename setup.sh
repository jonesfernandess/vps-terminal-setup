#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# setup.sh — Installs zellij, starship, zsh-autosuggestions, zsh-completions
# and configures zsh on macOS, Linux, or Windows (WSL/Git Bash).
# =============================================================================

ZELLIJ_CONFIG_DIR="${HOME}/.config/zellij"
ZSHRC="${HOME}/.zshrc"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo "============================================"
    echo "  $1"
    echo "============================================"
    echo ""
}

print_step() {
    echo "-> $1"
}

print_done() {
    echo ""
    echo "[OK] $1"
}

print_warn() {
    echo "[!] $1"
}

command_exists() {
    command -v "$1" &>/dev/null
}

detect_os() {
    case "$(uname -s)" in
        Darwin)  echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

detect_linux_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    elif command_exists apk; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# -----------------------------------------------------------------------------
# Installers per OS
# -----------------------------------------------------------------------------

install_macos() {
    print_header "macOS detected"

    if ! command_exists brew; then
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    print_step "Installing packages via Homebrew..."
    brew install zellij starship zsh-autosuggestions zsh-completions zsh

    AUTOSUGGESTIONS_SOURCE="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    COMPLETIONS_FPATH="$(brew --prefix)/share/zsh-completions"
}

install_linux() {
    print_header "Linux detected"

    local package_manager
    package_manager=$(detect_linux_package_manager)

    # Install zsh first
    print_step "Installing zsh..."
    case "$package_manager" in
        apt)    sudo apt-get update && sudo apt-get install -y zsh curl git ;;
        dnf)    sudo dnf install -y zsh curl git ;;
        pacman) sudo pacman -Sy --noconfirm zsh curl git ;;
        zypper) sudo zypper install -y zsh curl git ;;
        apk)    sudo apk add zsh curl git ;;
        *)      print_warn "Unknown package manager. Install zsh, curl, and git manually."; return 1 ;;
    esac

    # Install starship
    if ! command_exists starship; then
        print_step "Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
    fi

    # Install zellij
    if ! command_exists zellij; then
        print_step "Installing Zellij..."
        local zellij_arch
        case "$(uname -m)" in
            x86_64)  zellij_arch="x86_64" ;;
            aarch64) zellij_arch="aarch64" ;;
            *)       print_warn "Unsupported architecture for Zellij: $(uname -m)"; return 1 ;;
        esac

        local zellij_tarball="zellij-${zellij_arch}-unknown-linux-musl.tar.gz"
        local zellij_latest_url
        zellij_latest_url=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest \
            | grep "browser_download_url.*${zellij_tarball}" \
            | cut -d '"' -f 4)

        curl -fsSL "$zellij_latest_url" -o "/tmp/${zellij_tarball}"
        tar -xzf "/tmp/${zellij_tarball}" -C /tmp
        sudo mv /tmp/zellij /usr/local/bin/zellij
        sudo chmod +x /usr/local/bin/zellij
        rm -f "/tmp/${zellij_tarball}"
    fi

    # Install zsh-autosuggestions
    local zsh_autosuggestions_dir="${HOME}/.zsh/zsh-autosuggestions"
    if [ ! -d "$zsh_autosuggestions_dir" ]; then
        print_step "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_autosuggestions_dir"
    fi

    # Install zsh-completions
    local zsh_completions_dir="${HOME}/.zsh/zsh-completions"
    if [ ! -d "$zsh_completions_dir" ]; then
        print_step "Installing zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions "$zsh_completions_dir"
    fi

    AUTOSUGGESTIONS_SOURCE="${zsh_autosuggestions_dir}/zsh-autosuggestions.zsh"
    COMPLETIONS_FPATH="${zsh_completions_dir}/src"
}

install_wsl() {
    print_header "WSL detected"
    install_linux
}

install_windows_native() {
    print_header "Windows (Git Bash / MSYS2) detected"

    print_warn "Zellij does not support native Windows."
    print_warn "For the full experience, use WSL (Windows Subsystem for Linux)."
    print_warn ""
    print_warn "To install WSL, open PowerShell as Admin and run:"
    print_warn "  wsl --install"
    print_warn ""
    print_warn "Then re-run this script inside WSL."
    exit 1
}

# -----------------------------------------------------------------------------
# Configure zsh
# -----------------------------------------------------------------------------

configure_zsh() {
    print_header "Configuring zsh"

    # Backup existing .zshrc if it exists
    if [ -f "$ZSHRC" ]; then
        local backup_path="${ZSHRC}.backup.$(date +%s)"
        cp "$ZSHRC" "$backup_path"
        print_step "Backed up existing .zshrc to ${backup_path}"
    fi

    # Only append our block if not already present
    local marker="# --- setup-vps: starship + autosuggestions ---"
    if grep -qF "$marker" "$ZSHRC" 2>/dev/null; then
        print_step "zsh config block already present in .zshrc, skipping."
        return
    fi

    print_step "Appending config to .zshrc..."
    cat >> "$ZSHRC" << EOF

${marker}
# Completions
fpath+="${COMPLETIONS_FPATH}"
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select

# Autosuggestions (accept with right arrow)
source "${AUTOSUGGESTIONS_SOURCE}"

# Starship prompt
eval "\$(starship init zsh)"
# --- end setup-vps ---
EOF

    print_done ".zshrc configured"
}

# -----------------------------------------------------------------------------
# Configure zellij
# -----------------------------------------------------------------------------

configure_zellij() {
    print_header "Configuring Zellij"

    mkdir -p "${ZELLIJ_CONFIG_DIR}"

    print_step "Copying Zellij config from repo..."
    cp "${SCRIPT_DIR}/zellij/config.kdl" "${ZELLIJ_CONFIG_DIR}/config.kdl"

    print_done "Zellij configured"
}

# -----------------------------------------------------------------------------
# Set zsh as default shell
# -----------------------------------------------------------------------------

set_default_shell() {
    local current_shell
    current_shell=$(basename "$SHELL")

    if [ "$current_shell" = "zsh" ]; then
        print_step "zsh is already the default shell."
        return
    fi

    local zsh_path
    zsh_path=$(which zsh)

    # Ensure zsh is in /etc/shells
    if ! grep -qF "$zsh_path" /etc/shells 2>/dev/null; then
        print_step "Adding ${zsh_path} to /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    print_step "Setting zsh as default shell..."
    chsh -s "$zsh_path"
    print_done "Default shell set to zsh (restart your terminal)"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    print_header "setup-vps"
    echo "Installs: zellij, starship, zsh-autosuggestions, zsh-completions"
    echo ""

    local os_type
    os_type=$(detect_os)
    echo "Detected OS: ${os_type}"

    case "$os_type" in
        macos)   install_macos ;;
        linux)   install_linux ;;
        wsl)     install_wsl ;;
        windows) install_windows_native ;;
        *)
            print_warn "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac

    configure_zsh
    configure_zellij
    set_default_shell

    print_header "Setup complete!"
    echo "Installed:"
    echo "  - zsh-autosuggestions (accept suggestions with right arrow)"
    echo "  - zsh-completions (tab completion for common tools)"
    echo "  - starship (minimal prompt)"
    echo "  - zellij (terminal multiplexer, theme: ${ZELLIJ_THEME})"
    echo ""
    echo "Usage:"
    echo "  zellij                 # start a session"
    echo "  zellij --layout dev    # start with dev layout (3 panes)"
    echo ""
    echo "Restart your terminal to apply all changes."
}

main "$@"
