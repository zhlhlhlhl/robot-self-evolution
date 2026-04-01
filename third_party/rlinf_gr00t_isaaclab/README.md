# RLinf + IsaacLab vendor module

This directory vendors the local `rlinf-gr00t-isaaclab` training stack into the `robot-self-evolution` repo.

## What this contains

- `RLinf/`: RLinf training code used in this workspace
- `IsaacLab-rlinf/`: IsaacLab tree used by the training setup
- `configs/`: local experiment configs
- `run_*.sh`: local training / evaluation entry scripts

## Main local additions in this snapshot

### Single-color lift tasks
Added three lift tasks for different cubes:
- `lift_red`
- `lift_blue`
- `lift_green`

These correspond to lifting different cubes in the shared tabletop scene.

### Joint RGB multitask lift training
Added a true joint training variant:
- `lift_rgb`
- per-environment target color is sampled at reset
- language instruction is generated dynamically per env
- reward / success are computed against the sampled target cube

This is implemented with minimal intrusion by adding a new RLinf IsaacLab wrapper env instead of rewriting the full upstream task stack.

## Important config / script entry points

### Joint RGB training config
- `configs/isaaclab_gr00t_4090_stage15_env16_lift_rgb.yaml`

### Joint RGB env config
- `RLinf/examples/embodiment/config/env/isaaclab_lift_rgb_cube.yaml`

### Single-color env configs
- `RLinf/examples/embodiment/config/env/isaaclab_lift_red_cube.yaml`
- `RLinf/examples/embodiment/config/env/isaaclab_lift_blue_cube.yaml`
- `RLinf/examples/embodiment/config/env/isaaclab_lift_green_cube.yaml`

### Main wrapper implementation
- `RLinf/rlinf/envs/isaaclab/tasks/stack_cube.py`
- `RLinf/rlinf/envs/isaaclab/__init__.py`

## Training / eval notes

This snapshot reflects a **local, stability-first** setup rather than the larger official example settings.

Key differences from the official stack-cube example include:
- task changed from stack-cube to lift-cube RGB multitask
- smaller env count (`16` vs official larger defaults)
- much smaller batch settings (`micro_batch_size=1`, `global_batch_size=1` in local config)
- shorter `seq_length=1024`
- single-device placement in local configs
- local path assumptions for checkpoints / logs / envs

## Local path assumptions

Several scripts and configs assume local machine paths such as:
- `/root/miniforge/envs/isaaclab-rlinf`
- `/share/liziwen/simulation/rlinf-gr00t-isaaclab`
- `/root/workspace/...`

These are preserved as-is in this vendor snapshot.

## Scope

This directory is intentionally a vendorized research/training module inside the larger RSE repo. It is not yet cleanly integrated into `src/rse/...` adapters.
