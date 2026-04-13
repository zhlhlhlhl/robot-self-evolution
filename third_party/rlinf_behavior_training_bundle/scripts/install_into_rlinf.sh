#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /abs/path/to/RLinf" >&2
  exit 1
fi

SRC_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )/overlay"
DST_DIR="$1"

if [[ ! -d "$DST_DIR" ]]; then
  echo "RLinf repo not found: $DST_DIR" >&2
  exit 1
fi

cp -av "$SRC_DIR/." "$DST_DIR/"
echo "Installed overlay into $DST_DIR"
