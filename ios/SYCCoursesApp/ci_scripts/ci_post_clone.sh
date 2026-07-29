#!/bin/sh

set -eu

# Xcode Cloud images do not currently expose Node.js or rsvg-convert, both of
# which are required by the "Build Course Pack Resources" Xcode build phase.
export HOMEBREW_NO_AUTO_UPDATE=1

missing_formulae=""

if ! command -v node >/dev/null 2>&1; then
  missing_formulae="node"
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  missing_formulae="${missing_formulae:+$missing_formulae }librsvg"
fi

if [ -n "$missing_formulae" ]; then
  brew install $missing_formulae
fi