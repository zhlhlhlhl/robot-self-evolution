#!/usr/bin/env bash
set -euo pipefail

# 多任务（红/蓝/绿）轮转训练：共享同一个权重链路，按轮次在三个颜色任务之间切换。
# 目标：得到一个能适配三种颜色抓取任务的单模型 checkpoint。
#
# 用法：
#   chmod +x run_gr00t_isaaclab_train_multitask_rgb.sh
#   ./run_gr00t_isaaclab_train_multitask_rgb.sh
#
# 可选环境变量：
#   ENV_PREFIX=/root/miniforge/envs/isaaclab-rlinf
#   DATA_ROOT=/share/liziwen/simulation/rlinf-gr00t-isaaclab
#   ROUNDS=2
#   EPOCHS_PER_TASK=20
#   TOTAL_ENVS=16
#   BASE_SFT_PATH=/share/liziwen/simulation/rlinf-gr00t-isaaclab/checkpoints/RLinf-Gr00t-SFT-Stack-cube

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_PREFIX="${ENV_PREFIX:-/root/miniforge/envs/isaaclab-rlinf}"
DATA_ROOT="${DATA_ROOT:-/share/liziwen/simulation/rlinf-gr00t-isaaclab}"
ROUNDS="${ROUNDS:-2}"
EPOCHS_PER_TASK="${EPOCHS_PER_TASK:-20}"
TOTAL_ENVS="${TOTAL_ENVS:-16}"
BASE_SFT_PATH="${BASE_SFT_PATH:-/share/liziwen/simulation/rlinf-gr00t-isaaclab/checkpoints/RLinf-Gr00t-SFT-Stack-cube}"

REPO_PATH="$PROJECT_ROOT/RLinf"
EMBODIED_PATH="$REPO_PATH/examples/embodiment"
LOG_ROOT="$DATA_ROOT/results"
RUN_ROOT="$LOG_ROOT/$(date +'%Y%m%d-%H%M%S')-isaaclab-gr00t-multitask-rgb"
mkdir -p "$RUN_ROOT"

CONFIGS=(
  "isaaclab_gr00t_4090_stage15_env16_lift_red"
  "isaaclab_gr00t_4090_stage15_env16_lift_blue"
  "isaaclab_gr00t_4090_stage15_env16_lift_green"
)

export CONDA_PREFIX="$ENV_PREFIX"
export PATH="$ENV_PREFIX/bin:$PATH"
export MUJOCO_GL=osmesa
export PYOPENGL_PLATFORM=osmesa
export HYDRA_FULL_ERROR=1
export TOKENIZERS_PARALLELISM=false
export OMNI_KIT_ACCEPT_EULA=YES
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/etc/vulkan/icd.d/nvidia_icd.json}"
export RAY_FORCE_MINIMAL_DASHBOARD=1
export RAY_memory_usage_threshold="${RAY_memory_usage_threshold:-0.995}"
export RAY_TMPDIR="${RAY_TMPDIR:-/home/robot/raytmp}"
export TMPDIR="${TMPDIR:-/home/robot/raytmp}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
export REPO_PATH
export EMBODIED_PATH
export DATA_ROOT
export PYTHONPATH="$ENV_PREFIX/lib/python3.11/site-packages:$REPO_PATH:${PYTHONPATH:-}"

cd "$REPO_PATH"

CURRENT_CKPT="$BASE_SFT_PATH"

find_latest_actor_ckpt() {
  local run_dir="$1"
  find "$run_dir" -type f -path '*/checkpoints/global_step_*/actor/model_state_dict/full_weights.pt' -printf '%T@ %p\n' \
    | sort -n \
    | tail -1 \
    | awk '{print $2}'
}

echo "[info] Run root: $RUN_ROOT"
echo "[info] Start checkpoint: $CURRENT_CKPT"
echo "[info] Rounds: $ROUNDS, epochs/task: $EPOCHS_PER_TASK"

for ((r=1; r<=ROUNDS; r++)); do
  echo "============================================================"
  echo "[info] Round $r / $ROUNDS"

  for cfg in "${CONFIGS[@]}"; do
    stage_dir="$RUN_ROOT/round${r}_${cfg}"
    mkdir -p "$stage_dir"

    echo "------------------------------------------------------------"
    echo "[info] Training config: $cfg"
    echo "[info] Stage dir: $stage_dir"
    echo "[info] Input ckpt: $CURRENT_CKPT"

    "$ENV_PREFIX/bin/ray" stop --force >/dev/null 2>&1 || true

    set +e
    "$ENV_PREFIX/bin/python" "$EMBODIED_PATH/train_embodied_agent.py" \
      --config-path "$PROJECT_ROOT/configs" \
      --config-name "$cfg" \
      runner.logger.log_path="$stage_dir" \
      runner.max_epochs="$EPOCHS_PER_TASK" \
      runner.ckpt_path="$CURRENT_CKPT" \
      env.train.total_num_envs="$TOTAL_ENVS" \
      env.eval.total_num_envs="$TOTAL_ENVS" \
      2>&1 | tee "$stage_dir/train.log"
    code=${PIPESTATUS[0]}
    set -e

    if [[ $code -ne 0 ]]; then
      echo "[error] Stage failed: $cfg (round $r), code=$code"
      exit $code
    fi

    latest_ckpt="$(find_latest_actor_ckpt "$stage_dir" || true)"
    if [[ -z "$latest_ckpt" || ! -f "$latest_ckpt" ]]; then
      echo "[error] No actor checkpoint found after stage: $cfg"
      exit 1
    fi

    CURRENT_CKPT="$latest_ckpt"
    echo "[done] Stage complete. Output ckpt: $CURRENT_CKPT"
  done
done

echo "============================================================"
echo "[done] Multitask RGB training complete."
echo "[done] Final checkpoint: $CURRENT_CKPT"
echo "[done] Run root: $RUN_ROOT"
