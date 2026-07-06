#!/usr/bin/env bash
#
# setup.sh
#
# Symlinks git-upstream-update.sh into $HOME/bin so it can be run from anywhere.
#
# Re-running this script is safe; the existing symlink is refreshed.

set -euo pipefail

# Directory this script lives in (so it works no matter where it's called from).
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/bin"

mkdir -p "$BIN_DIR"

link() {
    local src="$SRC_DIR/$1"
    local dst="$BIN_DIR/$1"

    [[ -f "$src" ]] || { echo "error: missing source $src" >&2; exit 1; }
    chmod +x "$src"

    # -f replaces an existing link/file; -n avoids descending into an existing
    # symlinked directory of the same name.
    ln -sfn "$src" "$dst"
    echo "linked $dst -> $src"
}

link "git-upstream-update.sh"

echo
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "note: $BIN_DIR is not on your PATH."
    echo "      add this to your shell rc (e.g. ~/.bashrc):"
    echo "          export PATH=\"\$HOME/bin:\$PATH\""
else
    echo "done. git-upstream-update.sh is available on your PATH."
fi
