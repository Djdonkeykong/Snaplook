# Environment Variables Deployment Guide

## Codemagic (Flutter App Build)

Set these in Codemagic's environment variables section for your workflow:

### Required (App will crash without these):
```bash
SUPABASE_URL=https://tlqpkoknwfptfzejpchy.supabase.co
SUPABASE_ANON_KEY=<your_new_rotated_anon_key>
SUPERWALL_API_KEY=<your_superwall_key>
```

### Strongly Recommended (App features won't work without these):
```bash
# Search functionality
SEARCHAPI_KEY=<your_searchapi_key>

# RevenueCat for payments (if migrating from Superwall)
REVENUECAT_API_KEY_ANDROID=<your_revenuecat_android_key>
REVENUECAT_API_KEY_IOS=<your_revenuecat_ios_key>
```

### Optional (Features work without these, but may have fallbacks):
```bash
# Image hosting (fallback to Supabase storage if not set)
CLOUDINARY_CLOUD_NAME=<your_cloudinary_cloud_name>
CLOUDINARY_API_KEY=<your_cloudinary_api_key>
CLOUDINARY_API_SECRET=<your_cloudinary_api_secret>

# Additional image sources
PEXELS_API_KEY=<your_pexels_key>
PIXABAY_API_KEY=<your_pixabay_key>
UNSPLASH_ACCESS_KEY=<your_unsplash_key>

# Google OAuth
GOOGLE_CLIENT_ID=<your_google_client_id>
GOOGLE_SERVER_CLIENT_ID=<your_google_server_client_id>

# Apify (if used)
APIFY_API_TOKEN=<your_apify_token>

# Search location (defaults to no location filter)
SEARCHAPI_LOCATION=United States

# Feature flags
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
```

---

## Render (Python Backend Server)

Set these in your Render service's environment variables:

### Required (Server will crash without these):
```bash
SUPABASE_URL=https://tlqpkoknwfptfzejpchy.supabase.co
SUPABASE_SERVICE_KEY=<your_supabase_service_role_key>

# Cloudinary for image uploads
CLOUDINARY_CLOUD_NAME=<your_cloudinary_cloud_name>
CLOUDINARY_API_KEY=<your_cloudinary_api_key>
CLOUDINARY_API_SECRET=<your_cloudinary_api_secret>

# Search API
SEARCHAPI_KEY=<your_searchapi_key>
```

### Optional (Server works without these, uses defaults):
```bash
# Feature flags
CACHE_RESULTS=true                    # Cache detection results (default: false)
USE_ONNX=false                        # Use ONNX model instead of PyTorch (default: false)
LOG_LEVEL=INFO                        # Logging level (default: INFO)
CLOUDINARY_LOG_TIMING=false           # Log upload timing (default: false)

# Search configuration
SEARCHAPI_LOCATION=United States      # Default location for search results
SEARCHAPI_DEVICE=mobile               # Device type: mobile or desktop

# Detection tuning parameters (use defaults if not set)
CONF_THRESHOLD=0.275                  # Detection confidence threshold
EXPAND_RATIO=0.1                      # Bounding box expansion ratio
SHOE_EXPAND_RATIO=0.22                # Shoe-specific expansion
HAT_EXPAND_RATIO=0.18                 # Hat-specific expansion
MAX_GARMENTS=5                        # Max items to detect

# Image processing
CLOUDINARY_CROP_MAX_DIM=768           # Max dimension for cropped images
CLOUDINARY_FULL_MAX_DIM=1600          # Max dimension for full images
CLOUDINARY_CROP_QUALITY=72            # JPEG quality for crops
CLOUDINARY_FULL_QUALITY=80            # JPEG quality for full images

# RunPod (if using GPU inference)
USE_RUNPOD=false                      # Enable RunPod GPU inference
RUNPOD_API_KEY=<your_runpod_key>      # RunPod API key
RUNPOD_ENDPOINT_ID=<your_endpoint_id> # RunPod endpoint ID
```

---

## Key Differences

| Service | SUPABASE Key Type | Purpose |
|---------|------------------|---------|
| **Codemagic** | `SUPABASE_ANON_KEY` | Client-side authentication (public key) |
| **Render** | `SUPABASE_SERVICE_KEY` | Server-side admin access (secret key) |

**CRITICAL:**
- **Rotate `SUPABASE_ANON_KEY`** - The old one is exposed in git history
- Never use `SUPABASE_SERVICE_KEY` in the Flutter app
- Get the service key from: Supabase Dashboard > Project Settings > API > service_role key

---

## Codemagic Setup Instructions

1. Go to your Codemagic app settings
2. Navigate to **Environment variables**
3. Add each variable as a **Secure** variable (check the secure checkbox)
4. For the build command, Codemagic will automatically pass them to Flutter

**Note:** Codemagic passes environment variables differently than local development. You may need to configure your `codemagic.yaml` to use `--dart-define` for each variable, or use a pre-build script to generate a `.env` file.

---

## Render Setup Instructions

1. Go to your Render service dashboard
2. Navigate to **Environment** tab
3. Add each variable using the **Add Environment Variable** button
4. Click **Save Changes**
5. Render will automatically redeploy with new variables

---

## Security Checklist

Before going live:
- [ ] Rotated SUPABASE_ANON_KEY (exposed in git)
- [ ] Verified SUPABASE_SERVICE_KEY is only on Render (never in app)
- [ ] All API keys are marked as "Secure" in Codemagic
- [ ] Tested app build with production environment variables
- [ ] Verified backend server starts successfully on Render
- [ ] Checked that no .env file is committed to git
- [ ] Confirmed .env is in .gitignore
