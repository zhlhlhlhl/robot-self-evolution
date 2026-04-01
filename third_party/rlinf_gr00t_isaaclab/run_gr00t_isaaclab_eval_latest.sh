#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_PREFIX="${ENV_PREFIX:-/root/miniforge/envs/isaaclab-rlinf}"
DATA_ROOT="${DATA_ROOT:-/share/liziwen/simulation/rlinf-gr00t-isaaclab}"
CONFIG_NAME="${CONFIG_NAME:-isaaclab_gr00t_4090_stage15_env16}"
EVAL_ENVS="${EVAL_ENVS:-16}"
CLEAN_RAY_BEFORE_RUN="${CLEAN_RAY_BEFORE_RUN:-1}"

REPO_PATH="$PROJECT_ROOT/RLinf"
EMBODIED_PATH="$REPO_PATH/examples/embodiment"
LOG_ROOT="$DATA_ROOT/results"
RUN_LOG_DIR="$LOG_ROOT/$(date +'%Y%m%d-%H%M%S')-${CONFIG_NAME}-eval-latest"
mkdir -p "$RUN_LOG_DIR"

LATEST_CKPT_PT="$(
  find "$LOG_ROOT" -type f -path '*/checkpoints/global_step_*/actor/model_state_dict/full_weights.pt' -printf '%T@ %p\n' \
    | sort -n \
    | tail -1 \
    | awk '{print $2}'
)"

if [[ -z "${LATEST_CKPT_PT}" || ! -f "${LATEST_CKPT_PT}" ]]; then
  echo "[error] No RLinf checkpoint file found under: $LOG_ROOT"
  echo "        expected pattern: */checkpoints/global_step_*/actor/model_state_dict/full_weights.pt"
  exit 1
fi

LATEST_CKPT_DIR="$(dirname "$(dirname "$(dirname "$LATEST_CKPT_PT")")")"
LATEST_STEP="$(basename "$LATEST_CKPT_DIR")"

echo "[info] Using latest checkpoint: $LATEST_CKPT_PT"
echo "[info] Checkpoint step: $LATEST_STEP"
echo "[info] Eval logs/video dir: $RUN_LOG_DIR"

export CONDA_PREFIX="$ENV_PREFIX"
export PATH="$ENV_PREFIX/bin:$PATH"
export MUJOCO_GL=osmesa
export PYOPENGL_PLATFORM=osmesa
export HYDRA_FULL_ERROR=1
export TOKENIZERS_PARALLELISM=false
export OMNI_KIT_ACCEPT_EULA=YES
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/etc/vulkan/icd.d/nvidia_icd.json}"
export RAY_FORCE_MINIMAL_DASHBOARD=1
export RAY_memory_usage_threshold="${RAY_memory_usage_threshold:-0.99}"
export RAY_TMPDIR="${RAY_TMPDIR:-/home/robot/raytmp}"
export TMPDIR="${TMPDIR:-/home/robot/raytmp}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
export REPO_PATH
export EMBODIED_PATH
export DATA_ROOT
export PYTHONPATH="$ENV_PREFIX/lib/python3.11/site-packages:$REPO_PATH:${PYTHONPATH:-}"

cd "$REPO_PATH"

if [[ "$CLEAN_RAY_BEFORE_RUN" == "1" ]]; then
  "$ENV_PREFIX/bin/ray" stop --force >/dev/null 2>&1 || true
fi

"$ENV_PREFIX/bin/python" "$EMBODIED_PATH/eval_embodied_agent.py" \
  --config-path "$PROJECT_ROOT/configs" \
  --config-name "$CONFIG_NAME" \
  runner.logger.log_path="$RUN_LOG_DIR" \
  runner.ckpt_path="$LATEST_CKPT_PT" \
  env.eval.total_num_envs="$EVAL_ENVS" \
  env.eval.video_cfg.save_video=true \
  env.eval.video_cfg.info_on_video=true \
  env.eval.video_cfg.video_base_dir="$RUN_LOG_DIR/video/eval" \
  "$@" \
  2>&1 | tee "$RUN_LOG_DIR/eval.log"


echo "[done] Evaluation complete."
echo "[done] Log:   $RUN_LOG_DIR/eval.log"
echo "[done] Video: $RUN_LOG_DIR/video/eval"
