# ONNX Optimization Guide

This guide explains how to enable, disable, and troubleshoot ONNX-optimized inference for the YOLOS fashion detection model.

## What is ONNX?

ONNX (Open Neural Network Exchange) is an optimized inference runtime that's 2-3x faster than standard PyTorch. We've implemented it as a **feature flag** so you can easily switch between PyTorch and ONNX without code changes.

## Current Status

**Default mode: PyTorch** (safe, well-tested)
- USE_ONNX is set to `false` by default in render.yaml
- No action needed - server runs with standard PyTorch

## How to Enable ONNX (2-3x Speed Boost)

### Step 1: Export the Model Locally

Run this command in the `server/` directory:

```bash
python export_model_to_onnx.py
```

This creates `yolos_fashionpedia.onnx` file (~100MB). You only need to run this once.

### Step 2: Upload ONNX Model to Server

You need to get the ONNX file onto your Render server. Options:

**Option A: Add to Git (easiest)**
```bash
git add yolos_fashionpedia.onnx
git commit -m "Add ONNX model for faster inference"
git push
```

**Option B: Manual upload via Render SSH**
- Enable SSH on Render dashboard
- SCP the file to `/opt/render/project/src/server/`

### Step 3: Enable ONNX in Environment

In Render dashboard or render.yaml, change:

```yaml
- key: USE_ONNX
  value: "true"  # Changed from "false"
```

Deploy the change. The server will now use ONNX inference.

### Step 4: Verify

Check logs on first request:
```
[MODEL] Loading ONNX model in PID 123...
[MODEL] ONNX ready in PID 123
```

If you see "PyTorch" instead of "ONNX", the flag didn't take effect.

## How to Switch Back to PyTorch (Emergency Rollback)

**Instant rollback - no code changes needed:**

In Render dashboard, change environment variable:

```yaml
- key: USE_ONNX
  value: "false"
```

Or delete the environment variable entirely. Deploy, and server switches back to PyTorch immediately.

## Troubleshooting

### Error: "ONNX model not found"

**Problem:** Server can't find `yolos_fashionpedia.onnx`

**Solution:**
1. Make sure you ran `export_model_to_onnx.py` locally
2. Verify the .onnx file is in the `server/` directory
3. Check it's included in git or uploaded to Render

**Quick fix:** Set `USE_ONNX=false` to use PyTorch while you fix the file

### Detection Results Look Different

**Problem:** ONNX gives slightly different bounding boxes than PyTorch

**Solution:** This is expected - small numerical differences are normal. If differences are significant (>5% score/bbox changes), report as bug and switch back to PyTorch.

### Server Crashes on First Request

**Problem:** ONNX runtime fails to load

**Solution:**
1. Check `onnxruntime` is in requirements.txt
2. Verify pip install completed successfully in build logs
3. Set `USE_ONNX=false` and use PyTorch while investigating

### Performance Not Improved

**Problem:** ONNX is not 2-3x faster

**Solution:**
1. Verify logs show "Loading ONNX model" not "Loading PyTorch"
2. Check USE_ONNX=true in environment variables
3. Run multiple tests - first request loads model, subsequent requests show true speed

## Performance Comparison

**Before (PyTorch):**
- Detection time: 5-8 seconds
- Total pipeline: 9-10 seconds

**Expected with ONNX:**
- Detection time: 2-4 seconds (2-3x faster)
- Total pipeline: 6-7 seconds

Actual results may vary based on image size and complexity.

## File Locations

- **Export script:** `server/export_model_to_onnx.py`
- **ONNX model:** `server/yolos_fashionpedia.onnx` (created by export)
- **Inference code:** `server/fashion_detector_server.py` (lines 1128-1171)
- **Feature flag:** render.yaml line 33 or Render dashboard

## How the Code Works

The implementation uses a feature flag pattern:

```python
USE_ONNX = os.getenv("USE_ONNX", "false").lower() in {"1", "true", "yes"}

if USE_ONNX:
    # Load ONNX runtime and run fast inference
    onnx_session = ort.InferenceSession(...)
else:
    # Load PyTorch model and run standard inference
    model = YolosForObjectDetection.from_pretrained(...)
```

Both code paths are **always present** - only one executes based on the flag. This means:
- Zero risk of breaking PyTorch path
- Instant rollback by changing one environment variable
- Easy A/B testing between modes

## Questions?

If anything goes wrong:
1. Set `USE_ONNX=false` to immediately switch back
2. Check server logs for error messages
3. Verify ONNX model file exists and is accessible
4. Test locally first before deploying to production
