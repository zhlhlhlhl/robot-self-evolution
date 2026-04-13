#!/usr/bin/env bash
set -euo pipefail

# Test a BEHAVIOR policy on the current task and render evaluation video.
#
# Usage examples:
#   ./test_behavior_model_video.sh
#   ./test_behavior_model_video.sh --ckpt /path/to/model.pt
#   ./test_behavior_model_video.sh --resume-dir /path/to/checkpoints/global_step_40
#   ./test_behavior_model_video.sh --activity turning_on_radio --instance-id 0 --max-steps 500
#
# Notes:
# - If neither --ckpt nor --resume-dir is provided, the script evaluates the base model
#   defined by the config (e.g. /share/liziwen/simulation/RLinf-OpenVLAOFT-Behavior/).
# - For RLinf training outputs, prefer --resume-dir. The script will resolve
#   <resume-dir>/actor/model_state_dict/full_weights.pt automatically.
# - Video files are saved under: <log_dir>/video/eval/

EMBODIED_PATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
REPO_PATH="$(dirname "$(dirname "$EMBODIED_PATH")")"
SRC_FILE="${EMBODIED_PATH}/eval_embodied_agent.py"
CONFIG_NAME="behavior_ppo_openvlaoft"
ROBOT_PLATFORM_DEFAULT="LIBERO"

CKPT_PATH=""
RESUME_DIR=""
ACTIVITY_NAME=""
ACTIVITY_DEFINITION_ID=""
ACTIVITY_INSTANCE_ID=""
SCENE_MODEL=""
MAX_STEPS="500"
ACTION_CHUNKS="8"
LOG_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ckpt)
            CKPT_PATH="$2"
            shift 2
            ;;
        --resume-dir)
            RESUME_DIR="$2"
            shift 2
            ;;
        --activity)
            ACTIVITY_NAME="$2"
            shift 2
            ;;
        --definition-id)
            ACTIVITY_DEFINITION_ID="$2"
            shift 2
            ;;
        --instance-id)
            ACTIVITY_INSTANCE_ID="$2"
            shift 2
            ;;
        --scene-model)
            SCENE_MODEL="$2"
            shift 2
            ;;
        --max-steps)
            MAX_STEPS="$2"
            shift 2
            ;;
        --config-name)
            CONFIG_NAME="$2"
            shift 2
            ;;
        --action-chunks)
            ACTION_CHUNKS="$2"
            shift 2
            ;;
        --log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        -h|--help)
            sed -n '1,40p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -n "$CKPT_PATH" && -n "$RESUME_DIR" ]]; then
    echo "Use either --ckpt or --resume-dir, not both." >&2
    exit 1
fi

if [[ -n "$RESUME_DIR" ]]; then
    RESOLVED_CKPT_PATH="$RESUME_DIR/actor/model_state_dict/full_weights.pt"
    if [[ ! -f "$RESOLVED_CKPT_PATH" ]]; then
        echo "Checkpoint not found under resume dir: $RESOLVED_CKPT_PATH" >&2
        exit 1
    fi
    CKPT_PATH="$RESOLVED_CKPT_PATH"
fi

if ! [[ "$ACTION_CHUNKS" =~ ^[1-9][0-9]*$ ]]; then
    echo "--action-chunks must be a positive integer, got: $ACTION_CHUNKS" >&2
    exit 1
fi
if ! [[ "$MAX_STEPS" =~ ^[1-9][0-9]*$ ]]; then
    echo "--max-steps must be a positive integer, got: $MAX_STEPS" >&2
    exit 1
fi
if (( MAX_STEPS % ACTION_CHUNKS != 0 )); then
    ADJUSTED_MAX_STEPS=$(( (MAX_STEPS / ACTION_CHUNKS + 1) * ACTION_CHUNKS ))
    echo "[test_behavior_model_video] Adjusting --max-steps from ${MAX_STEPS} to ${ADJUSTED_MAX_STEPS} so it is divisible by action chunks (${ACTION_CHUNKS})."
    MAX_STEPS="$ADJUSTED_MAX_STEPS"
fi

if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR="${REPO_PATH}/logs/$(date +'%Y%m%d-%H:%M:%S')-behavior-model-video-test"
fi
mkdir -p "$LOG_DIR"
MEGA_LOG_FILE="${LOG_DIR}/eval_embodiment.log"

export EMBODIED_PATH
export REPO_PATH
export SRC_FILE
export PATH="${REPO_PATH}/.venv/bin:$PATH"

export MUJOCO_GL=egl
export PYOPENGL_PLATFORM=egl
export ROBOTWIN_PATH=${ROBOTWIN_PATH:-/path/to/RoboTwin}
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
if [[ -z "${OMNIGIBSON_DATA_PATH:-}" ]]; then
    if [[ -d "/share/liziwen/simulation/behavior-1k-assets" && -d "/share/liziwen/simulation/omnigibson-robot-assets" ]]; then
        export OMNIGIBSON_DATA_PATH="/share/liziwen/simulation"
    elif [[ -d "${REPO_PATH}/.venv/BEHAVIOR-1K/datasets/behavior-1k-assets" ]]; then
        export OMNIGIBSON_DATA_PATH="${REPO_PATH}/.venv/BEHAVIOR-1K/datasets"
    else
        echo "Cannot determine OMNIGIBSON_DATA_PATH automatically." >&2
        exit 1
    fi
fi
export OMNIGIBSON_DATASET_PATH=${OMNIGIBSON_DATASET_PATH:-$OMNIGIBSON_DATA_PATH/behavior-1k-assets}
export OMNIGIBSON_KEY_PATH=${OMNIGIBSON_KEY_PATH:-$OMNIGIBSON_DATA_PATH/omnigibson.key}
export OMNIGIBSON_ASSET_PATH=${OMNIGIBSON_ASSET_PATH:-$OMNIGIBSON_DATA_PATH/omnigibson-robot-assets}
export OMNIGIBSON_HEADLESS=${OMNIGIBSON_HEADLESS:-1}

export ISAAC_PATH=${ISAAC_PATH:-/path/to/isaac-sim}
export EXP_PATH=${EXP_PATH:-$ISAAC_PATH/apps}
export CARB_APP_PATH=${CARB_APP_PATH:-$ISAAC_PATH/kit}

export HYDRA_FULL_ERROR=1
export ROBOT_PLATFORM=${ROBOT_PLATFORM:-$ROBOT_PLATFORM_DEFAULT}

declare -a CMD
CMD=(python "$SRC_FILE" --config-path "$EMBODIED_PATH/config/" --config-name "$CONFIG_NAME"
    runner.logger.log_path="$LOG_DIR"
    env.eval.total_num_envs=1
    env.eval.max_steps_per_rollout_epoch="$MAX_STEPS"
    env.eval.max_episode_steps="$MAX_STEPS"
    env.eval.video_cfg.save_video=True
    env.eval.video_cfg.info_on_video=True
    env.eval.video_cfg.video_base_dir="$LOG_DIR/video/eval"
    env.train.video_cfg.save_video=False)

if [[ -n "$CKPT_PATH" ]]; then
    CMD+=(runner.ckpt_path="$CKPT_PATH")
fi
if [[ -n "$ACTIVITY_NAME" ]]; then
    CMD+=(env.eval.omni_config.task.activity_name="$ACTIVITY_NAME")
    CMD+=(env.train.omni_config.task.activity_name="$ACTIVITY_NAME")
fi
if [[ -n "$ACTIVITY_DEFINITION_ID" ]]; then
    CMD+=(env.eval.omni_config.task.activity_definition_id="$ACTIVITY_DEFINITION_ID")
    CMD+=(env.train.omni_config.task.activity_definition_id="$ACTIVITY_DEFINITION_ID")
fi
if [[ -n "$ACTIVITY_INSTANCE_ID" ]]; then
    CMD+=(env.eval.omni_config.task.activity_instance_id="$ACTIVITY_INSTANCE_ID")
    CMD+=(env.train.omni_config.task.activity_instance_id="$ACTIVITY_INSTANCE_ID")
fi
if [[ -n "$SCENE_MODEL" ]]; then
    CMD+=(env.eval.omni_config.scene.scene_model="$SCENE_MODEL")
    CMD+=(env.train.omni_config.scene.scene_model="$SCENE_MODEL")
fi

printf '%q ' "${CMD[@]}" | tee "$MEGA_LOG_FILE"
echo | tee -a "$MEGA_LOG_FILE"
"${CMD[@]}" 2>&1 | tee -a "$MEGA_LOG_FILE"

echo
echo "Done. Logs: $MEGA_LOG_FILE"
echo "Videos:   $LOG_DIR/video/eval"
