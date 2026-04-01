#!/usr/bin/env bash
set -euo pipefail

# 类似 run_gr00t_isaaclab_eval_latest.sh，但支持一次评估多个 config，并全部保存视频。
#
# 用法：
#   chmod +x run_gr00t_isaaclab_eval_batch_latest.sh
#   ./run_gr00t_isaaclab_eval_batch_latest.sh
#
# 可选环境变量：
#   CONFIG_NAMES="isaaclab_gr00t_4090_stage15_env16_lift_red isaaclab_gr00t_4090_stage15_env16_lift_blue isaaclab_gr00t_4090_stage15_env16_lift_green"
#   EVAL_ENVS=16
#   ENV_PREFIX=/root/miniforge/envs/isaaclab-rlinf
#   DATA_ROOT=/share/liziwen/simulation/rlinf-gr00t-isaaclab
#   CKPT_GLOB='*/checkpoints/global_step_*/actor/model_state_dict/full_weights.pt'

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_PREFIX="${ENV_PREFIX:-/root/miniforge/envs/isaaclab-rlinf}"
DATA_ROOT="${DATA_ROOT:-/share/liziwen/simulation/rlinf-gr00t-isaaclab}"
EVAL_ENVS="${EVAL_ENVS:-16}"

REPO_PATH="$PROJECT_ROOT/RLinf"
EMBODIED_PATH="$REPO_PATH/examples/embodiment"
LOG_ROOT="$DATA_ROOT/results"
CKPT_GLOB="${CKPT_GLOB:-*/checkpoints/global_step_*/actor/model_state_dict/full_weights.pt}"

# 默认跑 3 个例子；你也可以用 CONFIG_NAMES 环境变量覆盖
DEFAULT_CONFIGS=(
  "isaaclab_gr00t_4090_stage15_env16_lift_red"
  "isaaclab_gr00t_4090_stage15_env16_lift_blue"
  "isaaclab_gr00t_4090_stage15_env16_lift_green"
)

if [[ -n "${CONFIG_NAMES:-}" ]]; then
  read -r -a CONFIG_ARRAY <<<"$CONFIG_NAMES"
else
  CONFIG_ARRAY=("${DEFAULT_CONFIGS[@]}")
fi

if [[ ${#CONFIG_ARRAY[@]} -eq 0 ]]; then
  echo "[error] No config names provided." >&2
  exit 1
fi

LATEST_CKPT_PT="$({
  find "$LOG_ROOT" -type f -path "$CKPT_GLOB" -printf '%T@ %p\n' \
    | sort -n \
    | tail -1 \
    | awk '{print $2}'
} 2>/dev/null || true)"

if [[ -z "${LATEST_CKPT_PT}" || ! -f "${LATEST_CKPT_PT}" ]]; then
  echo "[error] No RLinf checkpoint file found under: $LOG_ROOT"
  echo "        expected pattern: $CKPT_GLOB"
  exit 1
fi

LATEST_CKPT_DIR="$(dirname "$(dirname "$(dirname "$LATEST_CKPT_PT")")")"
LATEST_STEP="$(basename "$LATEST_CKPT_DIR")"

RUN_ROOT="$LOG_ROOT/$(date +'%Y%m%d-%H%M%S')-batch-eval-latest-${LATEST_STEP}"
mkdir -p "$RUN_ROOT"

echo "[info] Using latest checkpoint: $LATEST_CKPT_PT"
echo "[info] Checkpoint step: $LATEST_STEP"
echo "[info] Batch output root: $RUN_ROOT"
echo "[info] Configs: ${CONFIG_ARRAY[*]}"

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

FAILED=0

for CONFIG_NAME in "${CONFIG_ARRAY[@]}"; do
  CFG_RUN_DIR="$RUN_ROOT/$CONFIG_NAME"
  mkdir -p "$CFG_RUN_DIR"

  echo "------------------------------------------------------------"
  echo "[info] Evaluating config: $CONFIG_NAME"
  echo "[info] Output dir: $CFG_RUN_DIR"

  set +e
  "$ENV_PREFIX/bin/python" "$EMBODIED_PATH/eval_embodied_agent.py" \
    --config-path "$PROJECT_ROOT/configs" \
    --config-name "$CONFIG_NAME" \
    runner.logger.log_path="$CFG_RUN_DIR" \
    runner.ckpt_path="$LATEST_CKPT_PT" \
    env.eval.total_num_envs="$EVAL_ENVS" \
    env.eval.video_cfg.save_video=true \
    env.eval.video_cfg.info_on_video=true \
    env.eval.video_cfg.video_base_dir="$CFG_RUN_DIR/video/eval" \
    2>&1 | tee "$CFG_RUN_DIR/eval.log"
  CODE=${PIPESTATUS[0]}
  set -e

  if [[ $CODE -ne 0 ]]; then
    echo "[error] $CONFIG_NAME failed with exit code: $CODE"
    FAILED=1
  else
    echo "[done] $CONFIG_NAME complete."
    echo "       log:   $CFG_RUN_DIR/eval.log"
    echo "       video: $CFG_RUN_DIR/video/eval"
  fi

done

echo "============================================================"
if [[ $FAILED -ne 0 ]]; then
  echo "[done] Batch finished with failures. Root: $RUN_ROOT"
  exit 1
fi

echo "[done] Batch evaluation complete. Root: $RUN_ROOT"
