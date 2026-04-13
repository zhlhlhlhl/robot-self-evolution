# UI Scene Editor

This bundle now includes a monitor-friendly scene editor launcher:

- `overlay/examples/embodiment/launch_behavior_scene_editor.py`
- `overlay/examples/embodiment/launch_behavior_scene_editor.sh`

It is not a full drag-and-drop BEHAVIOR task authoring product, but it gives you a practical OmniGibson / Isaac-Sim-style viewport session where you can:
- open an official BEHAVIOR scene model or an existing scene JSON
- visually move objects in the viewport
- inspect the scene with the viewer camera
- save the current scene JSON with a keyboard shortcut

## Install into RLinf first

```bash
cd third_party/rlinf_behavior_training_bundle
./scripts/install_into_rlinf.sh /abs/path/to/RLinf
```

## Start the editor on a machine with a display

```bash
cd /abs/path/to/RLinf/examples/embodiment
./launch_behavior_scene_editor.sh \
  --scene-model house_double_floor_lower \
  --output-scene /tmp/my_behavior_scene.json
```

Or reopen an existing scene JSON:

```bash
./launch_behavior_scene_editor.sh \
  --scene-file /tmp/my_behavior_scene.json \
  --output-scene /tmp/my_behavior_scene_v2.json
```

## Controls

- `SHIFT + left click + drag`: move an object in the viewport
- `WASD + mouse`: move the viewer camera
- `P`: print current camera pose
- `O`: save a screenshot from the viewer camera
- `Z`: save the current scene to `--output-scene`
- `ESC`: quit

## Faster opening modes

Only open structure:

```bash
./launch_behavior_scene_editor.sh \
  --scene-model house_double_floor_lower \
  --quick-structure-only \
  --output-scene /tmp/structure_only_scene.json
```

Only load selected room types:

```bash
./launch_behavior_scene_editor.sh \
  --scene-model house_double_floor_lower \
  --load-room-types living_room kitchen \
  --output-scene /tmp/living_room_kitchen_scene.json
```

## What the saved file is

The saved scene JSON is OmniGibson's full scene serialization. It comes from `env.scene.save(json_path=...)`, so it includes scene metadata, object init info, and state.

That is exactly why this workflow is better than trying to hand-write scene JSON.

## Important limitation

This editor helps with **scene layout**.

It does **not** graphically author the BEHAVIOR task logic itself. After saving the scene JSON, you still define the task separately through a BDDL / `predefined_problem` file.

## Next step after saving a scene

Use the custom-task launcher:

```bash
./train_custom_behavior.sh \
  --scene-file /tmp/my_behavior_scene.json \
  --problem-file /abs/path/to/my_task.bddl \
  --task-desc "put the mug on the table" \
  --max-steps 496 \
  --max-epochs 1
```
