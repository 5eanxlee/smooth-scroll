#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSUME_YES="${MOUSE_PLUS_PLUS_ASSUME_YES:-0}"

log() {
  printf "==> %s\n" "$1"
}

fail() {
  printf "Error: %s\n" "$1" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" == "1" ]]; then
    return 0
  fi

  printf "%s [y/N] " "$prompt"
  local response=""
  read "response?"
  [[ "$response" == "y" || "$response" == "Y" || "$response" == "yes" || "$response" == "YES" ]]
}

load_homebrew_shellenv() {
  if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
    return 0
  fi

  for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$brew_path" ]]; then
      eval "$("$brew_path" shellenv)"
      return 0
    fi
  done

  return 1
}

ensure_command_line_tools() {
  if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode command line tools"
    xcode-select --install >/dev/null 2>&1 || true
    fail "Finish the Xcode command line tools installer, then run ./bootstrap.sh again."
  fi

  if ! command -v swift >/dev/null 2>&1; then
    fail "Swift was not found. Install Xcode command line tools, then run ./bootstrap.sh again."
  fi
}

ensure_homebrew() {
  if load_homebrew_shellenv; then
    return 0
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required to install Homebrew."

  if ! confirm "Homebrew is required to install the app icon renderer. Install Homebrew now?"; then
    fail "Install Homebrew from https://brew.sh, then run ./bootstrap.sh again."
  fi

  log "Installing Homebrew"
  if [[ "$ASSUME_YES" == "1" ]]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  load_homebrew_shellenv || fail "Homebrew installed, but brew was not found on PATH. Open a new terminal and run ./bootstrap.sh again."
}

ensure_icon_renderer() {
  if command -v rsvg-convert >/dev/null 2>&1 ||
    command -v magick >/dev/null 2>&1 ||
    command -v convert >/dev/null 2>&1; then
    return 0
  fi

  ensure_homebrew
  log "Installing librsvg for app icon rendering"
  brew install librsvg
}

main() {
  cd "$ROOT_DIR"
  ensure_command_line_tools
  ensure_icon_renderer

  log "Installing Mouse++"
  ./install.sh
}

main "$@"
