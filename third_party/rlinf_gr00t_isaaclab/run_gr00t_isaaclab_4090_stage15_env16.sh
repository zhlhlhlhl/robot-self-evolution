#!/usr/bin/env bash
set -euo pipefail

EPOCHS="${1:-1}"
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_PREFIX="${ENV_PREFIX:-/root/miniforge/envs/isaaclab-rlinf}"
ISAACSIM_PATH="${ISAACSIM_PATH:-$PROJECT_ROOT/IsaacLab-rlinf/_isaac_sim}"
ISAACSIM_SETUP_SCRIPT="$PROJECT_ROOT/IsaacLab-rlinf/_isaac_sim/setup_conda_env.sh"
DATA_ROOT="${DATA_ROOT:-/share/liziwen/simulation/rlinf-gr00t-isaaclab}"
REPO_PATH="$PROJECT_ROOT/RLinf"
EMBODIED_PATH="$REPO_PATH/examples/embodiment"
LOG_ROOT="$DATA_ROOT/results"
RUN_LOG_DIR="$LOG_ROOT/$(date +'%Y%m%d-%H%M%S')-isaaclab-gr00t-4090-stage15-env16"
mkdir -p "$RUN_LOG_DIR"

export CONDA_PREFIX="$ENV_PREFIX"
export PATH="$ENV_PREFIX/bin:$PATH"
export PYTHONPATH="${PYTHONPATH:-}"
if [ -f "$ISAACSIM_SETUP_SCRIPT" ]; then
  # standalone Isaac Sim mode
  source "$ISAACSIM_SETUP_SCRIPT"
else
  echo "[info] Isaac Sim standalone setup not found; assuming pip-installed isaacsim in ENV_PREFIX."
fi

export ISAACSIM_PATH
export ISAACLAB_PATH="$PROJECT_ROOT/IsaacLab-rlinf"
export REPO_PATH
export EMBODIED_PATH
export DATA_ROOT
export MUJOCO_GL=osmesa
export PYOPENGL_PLATFORM=osmesa
export HYDRA_FULL_ERROR=1
export TOKENIZERS_PARALLELISM=false
export OMNI_KIT_ACCEPT_EULA=YES
export VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-/etc/vulkan/icd.d/nvidia_icd.json}
export RAY_FORCE_MINIMAL_DASHBOARD=1
export RAY_memory_usage_threshold=${RAY_memory_usage_threshold:-0.99}
export RAY_TMPDIR="/home/robot/raytmp"
export TMPDIR="/home/robot/raytmp"
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export PYTHONPATH="$ENV_PREFIX/lib/python3.11/site-packages:$REPO_PATH:${PYTHONPATH:-}"

cd "$REPO_PATH"
"$ENV_PREFIX/bin/python" "$EMBODIED_PATH/train_embodied_agent.py" \
  --config-path "$PROJECT_ROOT/configs" \
  --config-name isaaclab_gr00t_4090_stage15_env16 \
  actor.enable_offload=false \
  rollout.enable_offload=false \
  runner.max_epochs="$EPOCHS" \
  runner.logger.log_path="$RUN_LOG_DIR" \
  2>&1 | tee "$RUN_LOG_DIR/train.log"
