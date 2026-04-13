#!/usr/bin/env python3
"""Launch a UI-based BEHAVIOR scene editor on top of OmniGibson.

This script is meant for machines with a monitor. It launches OmniGibson in
non-headless mode, loads either an official BEHAVIOR scene model or a custom
scene JSON, enables viewer-camera teleoperation, and lets the user save the
current scene to JSON from the UI session.

Typical usage:

    python launch_behavior_scene_editor.py \
        --scene-model house_double_floor_lower \
        --output-scene /tmp/my_scene.json

    python launch_behavior_scene_editor.py \
        --scene-file /path/to/existing_scene.json \
        --output-scene /tmp/edited_scene.json

Controls:
- SHIFT + left click + drag: move an object in the viewport
- WASD / mouse: move the viewer camera (OmniGibson teleoperation)
- P: print current camera pose
- O: save a screenshot from the viewer camera
- Z: save current scene JSON to --output-scene
- ESC: quit
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import omnigibson as og
import omnigibson.lazy as lazy
from omegaconf import OmegaConf

from rlinf.envs.behavior.patch import install_patch
from rlinf.envs.behavior.utils import setup_omni_cfg


DEFAULT_ENV_CFG = Path(__file__).resolve().parent / "config" / "env" / "behavior_custom_r1pro.yaml"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Launch a UI editor for BEHAVIOR scenes.")
    parser.add_argument("--env-config", type=str, default=str(DEFAULT_ENV_CFG), help="Base RLinf BEHAVIOR env yaml.")
    parser.add_argument("--scene-model", type=str, default="house_double_floor_lower", help="Official BEHAVIOR scene model to load.")
    parser.add_argument("--scene-file", type=str, default=None, help="Existing scene JSON to open instead of scene-model.")
    parser.add_argument("--output-scene", type=str, required=True, help="Path to save the edited scene JSON when pressing Z.")
    parser.add_argument("--quick-structure-only", action="store_true", help="Only load building structure for faster opening.")
    parser.add_argument("--load-room-types", type=str, nargs="*", default=None, help="Optional room-type filter, e.g. living_room kitchen")
    parser.add_argument("--robot", type=str, default="R1Pro", help="Robot type from the env yaml; default keeps R1Pro.")
    parser.add_argument("--task-desc", type=str, default="edit the scene", help="Language instruction stored in the config for consistency.")
    return parser.parse_args()


def build_cfg(args: argparse.Namespace):
    cfg = OmegaConf.load(args.env_config)

    OmegaConf.update(cfg, "omni_config.macro.headless", False, merge=False)
    OmegaConf.update(cfg, "omni_config.macro.render_viewer_camera", True, merge=False)
    OmegaConf.update(cfg, "omni_config.task.use_presampled_robot_pose", False, merge=False)
    OmegaConf.update(cfg, "omni_config.task.online_object_sampling", False, merge=False)
    OmegaConf.update(cfg, "omni_config.task.instance_resample_mode", "disabled", merge=False)
    OmegaConf.update(cfg, "omni_config.task.task_description_override", args.task_desc, merge=False)
    OmegaConf.update(cfg, "omni_config.scene.scene_model", args.scene_model, merge=False)
    OmegaConf.update(cfg, "omni_config.scene.scene_instance", None, merge=False)

    if args.scene_file is not None:
        OmegaConf.update(cfg, "omni_config.scene.scene_file", args.scene_file, merge=False)
    else:
        OmegaConf.update(cfg, "omni_config.scene.scene_file", None, merge=False)

    if args.quick_structure_only:
        OmegaConf.update(
            cfg,
            "omni_config.scene.load_object_categories",
            ["floors", "walls", "ceilings"],
            merge=False,
        )
    if args.load_room_types is not None and len(args.load_room_types) > 0:
        OmegaConf.update(cfg, "omni_config.scene.load_room_types", list(args.load_room_types), merge=False)

    if OmegaConf.select(cfg, "omni_config.robots[0].type", default=None) is not None:
        OmegaConf.update(cfg, "omni_config.robots[0].type", args.robot, merge=False)

    return cfg


def main() -> None:
    args = parse_args()
    output_scene = Path(args.output_scene).expanduser().resolve()
    output_scene.parent.mkdir(parents=True, exist_ok=True)

    install_patch()
    cfg = build_cfg(args)
    omni_cfg = setup_omni_cfg(cfg)
    env = og.Environment(configs=OmegaConf.to_container(omni_cfg, resolve=True))

    og.sim.enable_viewer_camera_teleoperation()

    print("\nBEHAVIOR scene editor is running.\n")
    print("Controls:")
    print("  SHIFT + left click + drag  -> move an object")
    print("  WASD + mouse              -> move the viewer camera")
    print("  P                         -> print viewer camera pose")
    print("  O                         -> save a screenshot")
    print(f"  Z                         -> save current scene to {output_scene}")
    print("  ESC                       -> quit")
    print("\nNotes:")
    print("  - This is a scene-layout editor, not a full BEHAVIOR task GUI authoring tool.")
    print("  - After saving scene JSON, define the task separately in a BDDL / predefined_problem file.")

    finished = {"quit": False}

    def save_scene():
        env.scene.save(json_path=str(output_scene))
        print(f"[scene-editor] Saved scene to {output_scene}")

    def quit_scene():
        finished["quit"] = True

    from omnigibson.utils.ui_utils import KeyboardEventHandler

    KeyboardEventHandler.add_keyboard_callback(lazy.carb.input.KeyboardInput.Z, save_scene)
    KeyboardEventHandler.add_keyboard_callback(lazy.carb.input.KeyboardInput.ESCAPE, quit_scene)

    try:
        while not finished["quit"]:
            env.step([])
    finally:
        og.shutdown()


if __name__ == "__main__":
    # Help some UI setups behave more like interactive Isaac Sim sessions.
    os.environ.setdefault("OMNIGIBSON_HEADLESS", "0")
    main()
