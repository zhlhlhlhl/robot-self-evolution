# Setup

This bundle assumes you already have a working RLinf checkout and a BEHAVIOR / OmniGibson-capable environment.

## 1. Base software

Validated against a local RLinf checkout with:
- Python virtualenv at `RLinf/.venv`
- OmniGibson / Isaac Sim dependencies already installed through RLinf's BEHAVIOR setup
- NVIDIA driver with EGL available at `/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0`

## 2. Required asset paths

The launchers expect one of these layouts:

### Preferred local layout

```bash
/share/liziwen/simulation/
├── behavior-1k-assets/
├── omnigibson-robot-assets/
├── omnigibson.key
└── RLinf-OpenVLAOFT-Behavior/
```

### Fallback layout

If not present, the scripts fall back to the RLinf checkout under:

```bash
$RLINF_REPO/.venv/BEHAVIOR-1K/datasets
```

## 3. Important environment variables

These are handled automatically by the included shell scripts, but they matter:

```bash
export XDG_RUNTIME_DIR=/tmp/xdg-runtime
export VK_ICD_FILENAMES=/tmp/nvidia_egl_icd.json
export VK_DRIVER_FILES=/tmp/nvidia_egl_icd.json
export OMNIGIBSON_DATA_PATH=/share/liziwen/simulation
export OMNIGIBSON_DATASET_PATH=/share/liziwen/simulation/behavior-1k-assets
export OMNIGIBSON_KEY_PATH=/share/liziwen/simulation/omnigibson.key
export OMNIGIBSON_ASSET_PATH=/share/liziwen/simulation/omnigibson-robot-assets
```

## 4. Why the Vulkan fix exists

On the validated machine, default Vulkan loader negotiation picked the wrong ICD path for Isaac Sim / OmniGibson in headless mode. Forcing the NVIDIA EGL ICD made BEHAVIOR startup succeed.

## 5. Known rendering limitation on A100 / A800 / H100-like GPUs

BEHAVIOR visuals can look poor on GPUs without hardware ray tracing. Two reasons matter:
- OmniGibson relies heavily on RTX renderer settings.
- RLinf video export records low-resolution policy observations by default, not a high-resolution viewer stream.

This bundle does not magically remove that hardware limitation, but it does expose camera-resolution overrides in the custom launcher and keeps eval video export working.
