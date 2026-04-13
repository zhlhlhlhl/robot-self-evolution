#!/usr/bin/env bash
set -euo pipefail

EMBODIED_PATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
REPO_PATH="$(dirname "$(dirname "$EMBODIED_PATH")")"
SRC_FILE="${EMBODIED_PATH}/launch_behavior_scene_editor.py"

if [ -x "${REPO_PATH}/.venv/bin/python" ]; then
    export PATH="${REPO_PATH}/.venv/bin:${PATH}"
fi

export MUJOCO_GL="egl"
export PYOPENGL_PLATFORM="egl"
export ROBOTWIN_PATH=${ROBOTWIN_PATH:-"/path/to/RoboTwin"}
export PYTHONPATH="${REPO_PATH}:${ROBOTWIN_PATH}:${PYTHONPATH:-}"

export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-runtime}
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" || true

export OMNIGIBSON_NO_OMNI_LOGS=${OMNIGIBSON_NO_OMNI_LOGS:-1}
export OMNIGIBSON_DEBUG=${OMNIGIBSON_DEBUG:-0}
export OMNIGIBSON_HEADLESS=0

if [ -z "${OMNIGIBSON_DATA_PATH:-}" ]; then
    if [ -d "/share/liziwen/simulation/behavior-1k-assets" ] && [ -d "/share/liziwen/simulation/omnigibson-robot-assets" ]; then
        export OMNIGIBSON_DATA_PATH="/share/liziwen/simulation"
    elif [ -d "${REPO_PATH}/.venv/BEHAVIOR-1K/datasets/behavior-1k-assets" ]; then
        export OMNIGIBSON_DATA_PATH="${REPO_PATH}/.venv/BEHAVIOR-1K/datasets"
    fi
fi
export OMNIGIBSON_DATASET_PATH=${OMNIGIBSON_DATASET_PATH:-$OMNIGIBSON_DATA_PATH/behavior-1k-assets/}
export OMNIGIBSON_KEY_PATH=${OMNIGIBSON_KEY_PATH:-$OMNIGIBSON_DATA_PATH/omnigibson.key}
export OMNIGIBSON_ASSET_PATH=${OMNIGIBSON_ASSET_PATH:-$OMNIGIBSON_DATA_PATH/omnigibson-robot-assets/}

export ISAAC_PATH=${ISAAC_PATH:-/path/to/isaac-sim}
export EXP_PATH=${EXP_PATH:-$ISAAC_PATH/apps}
export CARB_APP_PATH=${CARB_APP_PATH:-$ISAAC_PATH/kit}

exec python "$SRC_FILE" "$@"
