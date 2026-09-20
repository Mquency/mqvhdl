#!/usr/bin/env bash
#
# mqvhdl installer — https://github.com/mquency/mqvhdl
#
# Installs the mqvhdl executable (a single bash script) into a bin
# directory on your PATH. Default target: ~/.local/bin (user install).
#
# Remote one-liner:
#   curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/install.sh | bash -s --
#
# From a local clone:
#   ./install.sh

# The installer must run under bash. This first check is POSIX so that
# 'curl ... | sh' fails with a helpful message instead of syntax errors.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "mqvhdl installer: this must run under bash:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/install.sh | bash -s --" >&2
  exit 1
fi

set -euo pipefail

# ─────────────────────────────────────────────
# Defaults (overridable via flags or environment)
# ─────────────────────────────────────────────

REPO="${MQVHDL_REPO:-mquency/mqvhdl}"
REF="${MQVHDL_VERSION:-latest}"            # latest | HEAD | <tag> | <branch>
PREFIX="${MQVHDL_PREFIX:-$HOME/.local}"
WANT_SHA="${MQVHDL_SHA256:-}"

REF_EXPLICIT=0
ADD_PATH=0
UNINSTALL=0
NO_CHECK_DEPS=0
SUDO=""
TMP_FILE=""

# ─────────────────────────────────────────────
# Output helpers
# ─────────────────────────────────────────────

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; BOLD=""; DIM=""; RESET=""
fi

info()    { printf '%s\n' "${BLUE}→${RESET} $*"; }
success() { printf '%s\n' "${GREEN}✓${RESET} $*"; }
warn()    { printf '%s\n' "${YELLOW}!${RESET} $*" >&2; }
error()   { printf '%s\n' "${RED}✗${RESET} $*" >&2; }
hint()    { printf '%s\n' "${DIM}  $*${RESET}" >&2; }
die()     { error "$1"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ─────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────

usage() {
  cat <<HELP
mqvhdl installer

Installs the mqvhdl executable (a single bash script) into a bin
directory on your PATH. Default target: $HOME/.local/bin (user install).

Usage:
  install.sh [options]

Options:
  --prefix <dir>      Install to <dir>/bin/mqvhdl   (default: $HOME/.local)
  --system            Install to /usr/local/bin (system-wide; uses sudo if needed)
  --ref <ref>         Install from a git ref: tag, branch, or HEAD
                      (default: latest GitHub release, falling back to HEAD)
  --add-path          Add the install bin directory to your shell rc file
                      when it is not already on PATH
  --uninstall         Remove mqvhdl from the known install locations
  --no-check-deps     Skip the advisory dependency checks
  --sha256 <hex>      Verify the downloaded file against this SHA-256
  -h, --help          Show this help

Environment overrides:
  MQVHDL_REPO=<owner/name>   GitHub repository   (default: mquency/mqvhdl)
  MQVHDL_VERSION=<ref>       Same as --ref
  MQVHDL_PREFIX=<dir>        Same as --prefix
  MQVHDL_SHA256=<hex>        Same as --sha256

Remote one-liners:
  curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/install.sh | bash -s --
  curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/install.sh | bash -s -- --ref v0.3.0

From a local clone:
  git clone https://github.com/mquency/mqvhdl && cd mqvhdl && ./install.sh

Upgrade:    run this installer again (it overwrites the old file)
Uninstall:  ./install.sh --uninstall   (or simply delete the installed file)
HELP
}

# ─────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --prefix)
      [[ -n "${2:-}" ]] || die "Missing value for --prefix"
      PREFIX="$2"; shift 2 ;;
    --system) PREFIX="/usr/local"; shift ;;
    --ref|--version)
      [[ -n "${2:-}" ]] || die "Missing value for $1"
      REF="$2"; REF_EXPLICIT=1; shift 2 ;;
    --add-path) ADD_PATH=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --no-check-deps) NO_CHECK_DEPS=1; shift ;;
    --sha256)
      [[ -n "${2:-}" ]] || die "Missing value for --sha256"
      WANT_SHA="$2"; shift 2 ;;
    *) die "Unknown option: $1 (see --help)" ;;
  esac
done

BIN_DIR="$PREFIX/bin"
TARGET="$BIN_DIR/mqvhdl"

# ─────────────────────────────────────────────
# Detect how the installer itself was invoked
# ─────────────────────────────────────────────

SELF="${BASH_SOURCE[0]:-$0}"
SOURCE_MODE="download"
SCRIPT_DIR=""

if [[ -f "$SELF" && "$SELF" != "bash" && "$SELF" != "sh" \
      && "$SELF" != "/dev/stdin" && "$SELF" != /dev/fd/* ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$SELF")" && pwd -P)"
  SOURCE_MODE="local"
fi

# ─────────────────────────────────────────────
# Uninstall
# ─────────────────────────────────────────────

do_uninstall() {
  local removed=0 t
  for t in "$TARGET" "$HOME/.local/bin/mqvhdl" "/usr/local/bin/mqvhdl"; do
    if [[ -e "$t" ]]; then
      if rm -f "$t" 2>/dev/null; then
        success "Removed $t"
        removed=1
      elif command_exists sudo && sudo rm -f "$t" 2>/dev/null; then
        success "Removed $t (via sudo)"
        removed=1
      else
        warn "Could not remove $t (permissions?)"
      fi
    fi
  done
  if (( removed == 0 )); then
    warn "No mqvhdl installation found in the usual locations."
  fi
  hint "Project caches and outputs live inside each project"
  hint "(.mqvhdl_modules/, build/). Use 'mqvhdl clean' there if needed."
}

# ─────────────────────────────────────────────
# Dependency checks (advisory — mqvhdl checks
# again at runtime)
# ─────────────────────────────────────────────

hash_tool() {
  if command_exists sha256sum; then printf 'sha256sum'; return 0; fi
  if command_exists shasum;    then printf 'shasum';    return 0; fi
  return 1
}

runtime_bash_version() {
  bash -c 'printf %s "$BASH_VERSION"' 2>/dev/null || true
}

bash_ok() {
  # Reads the version on stdin, exits 0 when >= 4.2
  awk -F. 'NR { exit !( ($1 > 4) || ($1 == 4 && $2 >= 2) ) }'
}

find_good_bash_on_macos() {
  local c v
  for c in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [[ -x "$c" ]]; then
      v="$("$c" -c 'printf %s "$BASH_VERSION"' 2>/dev/null || true)"
      if [[ -n "$v" ]] && printf '%s' "$v" | bash_ok 2>/dev/null; then
        printf '%s' "$c"
        return 0
      fi
    fi
  done
  return 1
}

pkg_hint() {
  if command_exists apt-get; then hint "sudo apt install ghdl gtkwave"
  elif command_exists dnf; then hint "sudo dnf install ghdl gtkwave"
  elif command_exists pacman; then hint "sudo pacman -S ghdl gtkwave"
  elif command_exists zypper; then hint "sudo zypper install ghdl gtkwave"
  elif command_exists apk; then hint "apk add ghdl gtkwave"
  elif command_exists brew; then hint "brew install ghdl gtkwave"
  else hint "See https://github.com/ghdl/ghdl and https://gtkwave.sourceforge.net/"
  fi
}

check_deps() {
  if (( NO_CHECK_DEPS )); then return 0; fi

  local missing=0 rbv c

  rbv="$(runtime_bash_version)"
  if [[ -n "$rbv" ]] && printf '%s' "$rbv" | bash_ok 2>/dev/null; then
    success "bash ${rbv} (mqvhdl needs >= 4.2)"
  else
    missing=1
    warn "bash >= 4.2 not found (mqvhdl requires it; found: '${rbv:-none}')"
    if [[ "$(uname -s)" == "Darwin" ]]; then
      local good
      good="$(find_good_bash_on_macos || true)"
      if [[ -n "$good" ]]; then
        hint "Found a newer bash at: $good"
        hint "Make sure its directory precedes /bin in PATH (mqvhdl uses '#!/usr/bin/env bash')."
      else
        hint "Install a newer bash:  brew install bash"
      fi
    else
      hint "Install bash >= 4.2 with your package manager."
    fi
  fi

  if hash_tool >/dev/null; then
    success "Hash tool found: $(hash_tool)"
  else
    missing=1
    warn "Neither sha256sum nor shasum found (needed by the mqvhdl build cache)."
  fi

  for c in ghdl gtkwave; do
    if command_exists "$c"; then
      success "$c found"
    else
      missing=1
      warn "$c not found (mqvhdl needs it at runtime)."
    fi
  done

  if (( missing )); then
    echo
    hint "Suggested install commands for this system:"
    pkg_hint
  fi
}

# ─────────────────────────────────────────────
# Source acquisition
# ─────────────────────────────────────────────

fetch() {  # fetch <url> <outfile>
  local url="$1" out="$2"
  if command_exists curl; then
    curl -fsSL --retry 3 -o "$out" "$url"
  elif command_exists wget; then
    wget -qO "$out" "$url"
  else
    return 2
  fi
}

fetch_stdout() {  # fetch_stdout <url>
  local url="$1"
  if command_exists curl; then
    curl -fsSL "$url"
  elif command_exists wget; then
    wget -qO- "$url"
  else
    return 2
  fi
}

resolve_ref() {
  # Prints the git ref to download from.
  if [[ "$REF" != "latest" ]]; then
    printf '%s' "$REF"
    return 0
  fi
  local json tag
  json="$(fetch_stdout "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null || true)"
  tag="$(printf '%s' "$json" \
         | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
         | head -n 1)"
  if [[ -n "$tag" ]]; then
    printf '%s' "$tag"
  else
    warn "Could not resolve the latest release — falling back to 'HEAD'."
    printf 'HEAD'
  fi
}

get_source() {
  if [[ "$SOURCE_MODE" == "local" ]]; then
    local f="$SCRIPT_DIR/mqvhdl"
    if [[ ! -f "$f" ]]; then
      hint "Run the installer from the repository root,"
      hint "or use the remote one-liner (see --help)."
      die "No 'mqvhdl' file found next to this installer ($SCRIPT_DIR)."
    fi
    if (( REF_EXPLICIT )); then
      warn "Ignoring --ref / MQVHDL_VERSION: installing from the local checkout."
    fi
    SRC_FILE="$f"
    info "Source: local checkout ($f)"
  else
    if ! command_exists curl && ! command_exists wget; then
      die "Downloading mqvhdl requires curl or wget."
    fi
    local effective url
    effective="$(resolve_ref)"
    url="https://raw.githubusercontent.com/$REPO/$effective/mqvhdl"
    TMP_FILE="$(mktemp)"
    trap 'rm -f "$TMP_FILE"' EXIT
    info "Downloading mqvhdl (ref: $effective) from github.com/$REPO"
    if ! fetch "$url" "$TMP_FILE"; then
      die "Download failed: $url"
    fi
    SRC_FILE="$TMP_FILE"
  fi
}

# ─────────────────────────────────────────────
# Validation (never install something that is
# not the mqvhdl script)
# ─────────────────────────────────────────────

validate_source() {
  local first
  first="$(head -n 1 "$SRC_FILE")"
  if [[ "$first" != "#!/usr/bin/env bash" ]]; then
    die "Refusing to install: file does not look like the mqvhdl script (bad shebang)."
  fi
  if ! grep -q 'mqvhdl' "$SRC_FILE"; then
    die "Refusing to install: file does not look like the mqvhdl script."
  fi
  if ! bash -n "$SRC_FILE" 2>/dev/null; then
    die "Refusing to install: syntax error in the mqvhdl script."
  fi

  if [[ -n "$WANT_SHA" ]]; then
    local got want
    if ! command_exists sha256sum && ! command_exists shasum; then
      die "--sha256 was requested but neither sha256sum nor shasum is available."
    fi
    if command_exists sha256sum; then
      got="$(sha256sum "$SRC_FILE" | cut -d' ' -f1)"
    else
      got="$(shasum -a 256 "$SRC_FILE" | cut -d' ' -f1)"
    fi
    want="$(printf '%s' "$WANT_SHA" | tr '[:upper:]' '[:lower:]')"
    if [[ "$got" != "$want" ]]; then
      die "SHA-256 mismatch: expected $want, got $got."
    fi
    success "SHA-256 verified."
  fi
}

# ─────────────────────────────────────────────
# Install
# ─────────────────────────────────────────────

install_binary() {
  if ! { mkdir -p "$BIN_DIR" 2>/dev/null && [[ -w "$BIN_DIR" ]]; }; then
    if command_exists sudo; then
      SUDO="sudo"
      info "Using sudo to create/write $BIN_DIR"
      $SUDO mkdir -p "$BIN_DIR"
    else
      die "Cannot write to $BIN_DIR and sudo is unavailable. Re-run as root for --system."
    fi
  fi
  if [[ -e "$TARGET" && ! -w "$TARGET" && -z "$SUDO" ]] && command_exists sudo; then
    SUDO="sudo"
    info "Using sudo to replace $TARGET"
  fi

  if [[ -e "$TARGET" ]]; then
    info "Replacing existing installation: $TARGET"
  fi

  $SUDO cp -f "$SRC_FILE" "$TARGET"
  $SUDO chmod 0755 "$TARGET"
}

# ─────────────────────────────────────────────
# PATH handling
# ─────────────────────────────────────────────

path_contains() {
  local dir="$1" p tilde="" IFS=:
  if [[ "$dir" == "$HOME"* ]]; then
    tilde='~'"${dir#"$HOME"}"
  fi
  for p in $PATH; do
    if [[ "$p" == "$dir" ]]; then return 0; fi
    if [[ -n "$tilde" && "$p" == "$tilde" ]]; then return 0; fi
  done
  return 1
}

rc_file() {
  case "${SHELL:-}" in
    */zsh) printf '%s\n' "$HOME/.zshrc" ;;
    *)     printf '%s\n' "$HOME/.bashrc" ;;
  esac
}

write_rc_entry() {
  local rc="$1"
  if grep -qs 'Added by mqvhdl installer' "$rc"; then
    hint "A PATH entry from this installer already exists in $rc."
    return 0
  fi
  {
    echo
    echo "# Added by mqvhdl installer"
    echo "export PATH=\"$BIN_DIR:\$PATH\""
  } >> "$rc"
  success "PATH entry added to $rc"
  hint "Restart your shell, or run:  source \"$rc\""
}

ensure_path() {
  if path_contains "$BIN_DIR"; then
    success "$BIN_DIR is on PATH"
    return 0
  fi
  echo
  warn "$BIN_DIR is not on your PATH."
  local rc
  rc="$(rc_file)"
  if (( ADD_PATH )); then
    write_rc_entry "$rc"
    return 0
  fi
  if [[ -t 0 ]]; then
    local ans
    printf '%s' "Add $BIN_DIR to PATH in $rc now? [y/N] "
    if read -r ans && [[ "$ans" =~ ^[Yy] ]]; then
      write_rc_entry "$rc"
      return 0
    fi
  fi
  hint "Add this line to $rc (or re-run the installer with --add-path):"
  hint "export PATH=\"$BIN_DIR:\$PATH\""
}

# ─────────────────────────────────────────────
# Final notes
# ─────────────────────────────────────────────

final_notes() {
  local ver=""
  ver="$("$TARGET" --version 2>/dev/null || true)"
  echo
  printf '%s%s%s\n' "$CYAN$BOLD" "mqvhdl installed" "$RESET"
  printf '  %s\n' "location : $TARGET"
  if [[ -n "$ver" ]]; then
    printf '  %s\n' "$ver"
  fi
  if [[ "$SOURCE_MODE" == "download" ]]; then
    printf '  %s\n' "source   : github.com/$REPO"
  fi
  echo
  hint "Getting started : mqvhdl init   (then mqvhdl help)"
  hint "Upgrade         : re-run this installer (optionally with --ref <tag>)"
  hint "Uninstall       : this installer with --uninstall, or delete the file above"
  echo
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

main() {
  if (( UNINSTALL )); then
    do_uninstall
    exit 0
  fi

  echo
  printf '%s%s%s\n' "$CYAN$BOLD" "mqvhdl installer" "$RESET"
  printf '%s%s%s\n' "$DIM" "────────────────────────────────────────" "$RESET"

  check_deps
  get_source
  validate_source
  install_binary
  if [[ -n "$TMP_FILE" ]]; then rm -f "$TMP_FILE"; TMP_FILE=""; fi
  ensure_path
  final_notes
}

main
