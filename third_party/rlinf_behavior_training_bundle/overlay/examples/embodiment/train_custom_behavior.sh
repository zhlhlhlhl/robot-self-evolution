#!/usr/bin/env bash
set -euo pipefail

EMBODIED_PATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
REPO_PATH="$(dirname "$(dirname "$EMBODIED_PATH")")"
SRC_FILE="${EMBODIED_PATH}/train_embodied_agent.py"
CUSTOM_ENV_TEMPLATE="${EMBODIED_PATH}/config/env/behavior_custom_r1pro.yaml"
CONFIG_NAME="behavior_custom_ppo_openvlaoft"
ROBOT_PLATFORM_DEFAULT="LIBERO"

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
export VK_ICD_FILENAMES=/tmp/nvidia_egl_icd.json
export VK_DRIVER_FILES="$VK_ICD_FILENAMES"
cat > "$VK_ICD_FILENAMES" <<'JSON'
{
  "file_format_version": "1.0.0",
  "ICD": {
    "library_path": "/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0",
    "api_version": "1.3.242"
  }
}
JSON

export OMNIGIBSON_NO_OMNI_LOGS=${OMNIGIBSON_NO_OMNI_LOGS:-1}
export OMNIGIBSON_DEBUG=${OMNIGIBSON_DEBUG:-0}
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
export OMNIGIBSON_HEADLESS=${OMNIGIBSON_HEADLESS:-1}
export ISAAC_PATH=${ISAAC_PATH:-/path/to/isaac-sim}
export EXP_PATH=${EXP_PATH:-$ISAAC_PATH/apps}
export CARB_APP_PATH=${CARB_APP_PATH:-$ISAAC_PATH/kit}

LOG_DIR=""
SCENE_FILE=""
TASK_DESC=""
PROBLEM_FILE=""
MAX_STEPS=""
MAX_EPOCHS=""
TRAIN_ENVS=""
EVAL_ENVS=""
HEAD_RES=""
WRIST_RES=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scene-file)
            SCENE_FILE="$2"
            shift 2
            ;;
        --problem-file)
            PROBLEM_FILE="$2"
            shift 2
            ;;
        --task-desc)
            TASK_DESC="$2"
            shift 2
            ;;
        --log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        --max-steps)
            MAX_STEPS="$2"
            shift 2
            ;;
        --max-epochs)
            MAX_EPOCHS="$2"
            shift 2
            ;;
        --train-envs)
            TRAIN_ENVS="$2"
            shift 2
            ;;
        --eval-envs)
            EVAL_ENVS="$2"
            shift 2
            ;;
        --head-res)
            HEAD_RES="$2"
            shift 2
            ;;
        --wrist-res)
            WRIST_RES="$2"
            shift 2
            ;;
        --)
            shift
            EXTRA_ARGS+=("$@")
            break
            ;;
        -h|--help)
            cat <<EOF
Usage:
  ./train_custom_behavior.sh --scene-file /abs/path/scene.json --problem-file /abs/path/task.bddl [options]

What this does:
  1. Uses RLinf's BEHAVIOR training pipeline
  2. Loads a custom scene JSON through omni_config.scene.scene_file
  3. Loads a custom BEHAVIOR problem string into omni_config.task.predefined_problem
  4. Uses omni_config.task.task_description_override as the policy instruction

Options:
  --scene-file   Absolute path to a custom OmniGibson / BEHAVIOR scene JSON
  --problem-file Absolute path to a file containing the full predefined_problem text
  --task-desc    Natural-language instruction for the policy
  --log-dir      Override output log directory
  --max-steps    Override env.{train,eval}.max_steps_per_rollout_epoch and max_episode_steps (rounded down to /8)
  --max-epochs   Override runner.max_epochs
  --train-envs   Override env.train.total_num_envs
  --eval-envs    Override env.eval.total_num_envs
  --head-res     Camera head resolution, e.g. 224,224 or 448,448
  --wrist-res    Camera wrist resolution, e.g. 224,224 or 448,448
  --             Pass extra Hydra overrides through to train_embodied_agent.py

Template to edit directly if you prefer:
  ${CUSTOM_ENV_TEMPLATE}
EOF
            exit 0
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$SCENE_FILE" ]]; then
    echo "--scene-file is required" >&2
    exit 1
fi
if [[ -z "$PROBLEM_FILE" ]]; then
    echo "--problem-file is required" >&2
    exit 1
fi
if [[ ! -f "$SCENE_FILE" ]]; then
    echo "Scene file not found: $SCENE_FILE" >&2
    exit 1
fi
if [[ ! -f "$PROBLEM_FILE" ]]; then
    echo "Problem file not found: $PROBLEM_FILE" >&2
    exit 1
fi

PROBLEM_TEXT="$(cat "$PROBLEM_FILE")"
if [[ -z "$TASK_DESC" ]]; then
    TASK_DESC="custom behavior task"
fi

if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR="${REPO_PATH}/logs/$(date +'%Y%m%d-%H:%M:%S')-${CONFIG_NAME}"
fi
mkdir -p "$LOG_DIR"
MEGA_LOG_FILE="${LOG_DIR}/run_embodiment.log"

TMP_CONFIG_DIR="$(mktemp -d /tmp/behavior-custom-config-XXXXXX)"
cleanup() {
    rm -rf "$TMP_CONFIG_DIR"
}
trap cleanup EXIT
mkdir -p "$TMP_CONFIG_DIR/env"

SCENE_FILE="$SCENE_FILE" \
PROBLEM_FILE="$PROBLEM_FILE" \
TASK_DESC="$TASK_DESC" \
CUSTOM_ENV_TEMPLATE="$CUSTOM_ENV_TEMPLATE" \
BASE_CUSTOM_CONFIG="${EMBODIED_PATH}/config/behavior_custom_ppo_openvlaoft.yaml" \
TMP_CONFIG_DIR="$TMP_CONFIG_DIR" \
python - <<'PY'
import os
from omegaconf import OmegaConf

env_template = os.environ["CUSTOM_ENV_TEMPLATE"]
base_config = os.environ["BASE_CUSTOM_CONFIG"]
out_dir = os.environ["TMP_CONFIG_DIR"]
scene_file = os.environ["SCENE_FILE"]
problem_file = os.environ["PROBLEM_FILE"]
task_desc = os.environ["TASK_DESC"]

cfg = OmegaConf.load(env_template)
problem_text = open(problem_file, "r", encoding="utf-8").read().rstrip() + "\n"

OmegaConf.update(cfg, "omni_config.scene.scene_file", scene_file, merge=False)
OmegaConf.update(cfg, "omni_config.task.predefined_problem", problem_text, merge=False)
OmegaConf.update(cfg, "omni_config.task.task_description_override", task_desc, merge=False)
OmegaConf.update(cfg, "omni_config.task.use_presampled_robot_pose", False, merge=False)
OmegaConf.update(cfg, "omni_config.task.online_object_sampling", False, merge=False)
OmegaConf.update(cfg, "omni_config.task.instance_resample_mode", "disabled", merge=False)

OmegaConf.save(cfg, os.path.join(out_dir, "env", "generated_behavior_custom_r1pro.yaml"), resolve=False)
base_text = open(base_config, "r", encoding="utf-8").read()
base_text = base_text.replace("env/behavior_custom_r1pro@env.train", "env/generated_behavior_custom_r1pro@env.train", 1)
base_text = base_text.replace("env/behavior_custom_r1pro@env.eval", "env/generated_behavior_custom_r1pro@env.eval", 1)
with open(os.path.join(out_dir, "generated_behavior_custom_ppo_openvlaoft.yaml"), "w", encoding="utf-8") as f:
    f.write(base_text)
PY

CMD=(python "$SRC_FILE" --config-path "$TMP_CONFIG_DIR" --config-name "generated_behavior_custom_ppo_openvlaoft" "runner.logger.log_path=${LOG_DIR}")

if [[ -n "$MAX_STEPS" ]]; then
    if ! [[ "$MAX_STEPS" =~ ^[1-9][0-9]*$ ]]; then
        echo "--max-steps must be a positive integer" >&2
        exit 1
    fi
    ADJUSTED_MAX_STEPS=$(( (MAX_STEPS / 8) * 8 ))
    if (( ADJUSTED_MAX_STEPS == 0 )); then
        ADJUSTED_MAX_STEPS=8
    fi
    echo "[train_custom_behavior] Using max steps ${ADJUSTED_MAX_STEPS} (must be divisible by 8)." | tee -a "$MEGA_LOG_FILE"
    CMD+=("env.train.max_steps_per_rollout_epoch=${ADJUSTED_MAX_STEPS}")
    CMD+=("env.eval.max_steps_per_rollout_epoch=${ADJUSTED_MAX_STEPS}")
    CMD+=("env.train.max_episode_steps=${ADJUSTED_MAX_STEPS}")
    CMD+=("env.eval.max_episode_steps=${ADJUSTED_MAX_STEPS}")
    CMD+=("env.train.omni_config.task.termination_config.max_steps=${ADJUSTED_MAX_STEPS}")
    CMD+=("env.eval.omni_config.task.termination_config.max_steps=${ADJUSTED_MAX_STEPS}")
fi

if [[ -n "$MAX_EPOCHS" ]]; then
    CMD+=("runner.max_epochs=${MAX_EPOCHS}")
fi
if [[ -n "$TRAIN_ENVS" ]]; then
    CMD+=("env.train.total_num_envs=${TRAIN_ENVS}")
fi
if [[ -n "$EVAL_ENVS" ]]; then
    CMD+=("env.eval.total_num_envs=${EVAL_ENVS}")
fi
if [[ -n "$HEAD_RES" ]]; then
    CMD+=("env.train.omni_config.camera.head_resolution=[${HEAD_RES}]")
    CMD+=("env.eval.omni_config.camera.head_resolution=[${HEAD_RES}]")
fi
if [[ -n "$WRIST_RES" ]]; then
    CMD+=("env.train.omni_config.camera.wrist_resolution=[${WRIST_RES}]")
    CMD+=("env.eval.omni_config.camera.wrist_resolution=[${WRIST_RES}]")
fi

CMD+=("${EXTRA_ARGS[@]}")

printf '%q ' "${CMD[@]}" > "$MEGA_LOG_FILE"
printf '\n' >> "$MEGA_LOG_FILE"
"${CMD[@]}" 2>&1 | tee -a "$MEGA_LOG_FILE"
