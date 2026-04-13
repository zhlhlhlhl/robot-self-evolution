# RLinf BEHAVIOR Training Bundle

This directory packages the working BEHAVIOR-related code changes from a local RLinf checkout into a single overlay that can be copied into another RLinf repo.

It includes:
- machine-validated BEHAVIOR launch fixes for headless Vulkan / OmniGibson startup
- a monitor-friendly UI scene editor launcher for manual scene layout and JSON export
- near-official `behavior_ppo_openvlaoft` training config and launcher
- an eval video script for testing a checkpoint and exporting MP4s
- a custom-task training entry that supports your own scene JSON + `predefined_problem`
- the `behavior_env.py` fallback needed so custom task names can still provide a language instruction

## Directory layout

- `overlay/`: files copied on top of an existing RLinf repo
- `scripts/install_into_rlinf.sh`: one-command installer into an RLinf checkout
- `docs/setup.md`: environment and dependency notes
- `docs/usage.md`: training, eval, and custom-task usage
- `docs/ui_scene_editor.md`: monitor-based scene editing workflow
- `examples/custom_problem_template.bddl`: minimal custom BEHAVIOR problem template

## What changed

### 1. Runtime fixes for BEHAVIOR on headless NVIDIA machines

`overlay/examples/embodiment/run_embodiment.sh` now:
- creates and exports `XDG_RUNTIME_DIR=/tmp/xdg-runtime`
- forces Vulkan to use NVIDIA EGL ICD via `/tmp/nvidia_egl_icd.json`
- auto-detects `OMNIGIBSON_DATA_PATH`
- derives `OMNIGIBSON_DATASET_PATH`, `OMNIGIBSON_KEY_PATH`, and `OMNIGIBSON_ASSET_PATH`

### 2. UI scene editor for machines with a display

`overlay/examples/embodiment/launch_behavior_scene_editor.py`
`overlay/examples/embodiment/launch_behavior_scene_editor.sh`
- launch OmniGibson in non-headless mode
- load either an official scene model or an existing scene JSON
- enable viewer-camera teleoperation
- save the current scene JSON by pressing `Z`

### 3. Official BEHAVIOR training path

`overlay/examples/embodiment/config/behavior_ppo_openvlaoft.yaml`
- keeps the OpenVLA-OFT + LoRA training path
- uses BEHAVIOR env counts / rollout lengths matching the validated setup

`overlay/examples/embodiment/config/env/behavior_r1pro.yaml`
- contains the BEHAVIOR task-instance loading improvements used in the validated run

### 4. Checkpoint eval + video export

`overlay/examples/embodiment/test_behavior_model_video.sh`
- runs `eval_embodied_agent.py`
- turns on eval video recording
- supports `--ckpt` or `--resume-dir`
- auto-resolves `resume-dir/actor/model_state_dict/full_weights.pt`
- auto-adjusts `--max-steps` so it is divisible by `action_chunks`

### 5. Custom scene + custom task RL training

`overlay/examples/embodiment/train_custom_behavior.sh`
- accepts a custom scene JSON and a custom BEHAVIOR / BDDL problem file
- generates a temporary Hydra config
- launches RL training through the standard RLinf embodied pipeline

`overlay/examples/embodiment/config/env/behavior_custom_r1pro.yaml`
- base custom-task env template

`overlay/examples/embodiment/config/behavior_custom_ppo_openvlaoft.yaml`
- top-level training config for custom BEHAVIOR tasks

`overlay/rlinf/envs/behavior/behavior_env.py`
- adds a fallback `task_description_override` path for custom task names not present in the built-in `behavior_task.jsonl`

## Installation

From this repository:

```bash
cd third_party/rlinf_behavior_training_bundle
./scripts/install_into_rlinf.sh /abs/path/to/RLinf
```

That copies `overlay/*` into your RLinf checkout.

## Next docs

- See `docs/setup.md` for environment configuration.
- See `docs/usage.md` for the exact train / eval / custom-task commands.
- See `docs/ui_scene_editor.md` for the monitor-based scene editing workflow.
