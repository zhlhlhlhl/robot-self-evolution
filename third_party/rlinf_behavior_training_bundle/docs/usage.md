# Usage

## 1. Install overlay into RLinf

```bash
cd third_party/rlinf_behavior_training_bundle
./scripts/install_into_rlinf.sh /abs/path/to/RLinf
```

## 2. Launch official BEHAVIOR training

Inside the RLinf repo:

```bash
cd /abs/path/to/RLinf/examples/embodiment
./run_embodiment.sh behavior_ppo_openvlaoft
```

Logs will be written under:

```bash
/abs/path/to/RLinf/logs/<timestamp>-behavior_ppo_openvlaoft/
```

## 3. Test a checkpoint and save eval video

### Evaluate the base model

```bash
cd /abs/path/to/RLinf/examples/embodiment
./test_behavior_model_video.sh
```

### Evaluate a trained checkpoint directory

```bash
./test_behavior_model_video.sh \
  --resume-dir /abs/path/to/RLinf/logs/<run>/behavior_ppo_openvlaoft/checkpoints/global_step_1
```

### Evaluate a specific task instance

```bash
./test_behavior_model_video.sh \
  --resume-dir /abs/path/to/RLinf/logs/<run>/behavior_ppo_openvlaoft/checkpoints/global_step_1 \
  --activity turning_on_radio \
  --instance-id 0 \
  --max-steps 500
```

Notes:
- `--resume-dir` is preferred for RLinf outputs.
- The script resolves `actor/model_state_dict/full_weights.pt` automatically.
- `--max-steps` is auto-adjusted upward so it is divisible by `action_chunks`.

## 4. Train on a custom scene and custom BEHAVIOR problem

Prepare:
- a custom scene JSON that OmniGibson can load
- a file containing the full `predefined_problem` text

Then run:

```bash
cd /abs/path/to/RLinf/examples/embodiment
./train_custom_behavior.sh \
  --scene-file /abs/path/to/my_behavior_scene.json \
  --problem-file /abs/path/to/my_task.bddl \
  --task-desc "put the mug on the table" \
  --max-steps 496 \
  --max-epochs 1
```

Optional overrides:

```bash
./train_custom_behavior.sh \
  --scene-file /abs/path/to/my_behavior_scene.json \
  --problem-file /abs/path/to/my_task.bddl \
  --task-desc "put the mug on the table" \
  --train-envs 1 \
  --eval-envs 1 \
  --head-res 448,448 \
  --wrist-res 448,448 \
  --max-steps 496 \
  --max-epochs 10
```

## 5. Files to edit directly

If you prefer editing config files instead of using launcher args:
- `examples/embodiment/config/env/behavior_custom_r1pro.yaml`
- `examples/embodiment/config/behavior_custom_ppo_openvlaoft.yaml`

## 6. Common failure modes

### `env.eval.max_steps_per_rollout_epoch must be divisible by actor.model.num_action_chunks`

Fix: use a rollout step count divisible by 8 for this setup.

### Env worker dies during startup because scenes cannot be found

Fix: verify these exist and point to the right root:
- `OMNIGIBSON_DATA_PATH`
- `OMNIGIBSON_DATASET_PATH`
- `OMNIGIBSON_KEY_PATH`
- `OMNIGIBSON_ASSET_PATH`

### Eval video looks blurry

That can be expected on non-RT GPUs and with default 224x224 observation cameras. Try larger camera resolutions for visualization-oriented runs.
