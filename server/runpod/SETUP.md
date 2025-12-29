# RunPod GPU Setup Guide

Get **10x faster** detection (5s → 0.5s) using RunPod serverless GPU.

## Cost Estimate

**Serverless (pay per request):**
- ~$0.0002-0.0005 per request (~$0.02 per 100 requests)
- $0.40/hour when actively processing
- **Recommended for testing** - only pay when used

**24/7 deployment:**
- ~$140-180/mo (RTX 3070/4090 GPU)
- Only if you have constant traffic

---

## Step 1: Create RunPod Account

1. Go to https://www.runpod.io/
2. Sign up (free account)
3. Add payment method (you get $10 free credit)

---

## Step 2: Build and Push Docker Image

### Option A: Use Docker Hub (Easiest)

```bash
# Navigate to runpod folder
cd server/runpod

# Build image
docker build -t your-dockerhub-username/snaplook-yolos:latest .

# Push to Docker Hub
docker login
docker push your-dockerhub-username/snaplook-yolos:latest
```

### Option B: Use GitHub Container Registry

```bash
cd server/runpod

# Build and tag
docker build -t ghcr.io/your-github-username/snaplook-yolos:latest .

# Login and push
echo $GITHUB_TOKEN | docker login ghcr.io -u your-github-username --password-stdin
docker push ghcr.io/your-github-username/snaplook-yolos:latest
```

---

## Step 3: Create RunPod Serverless Endpoint

1. **Go to RunPod Dashboard** → https://www.runpod.io/console/serverless
2. **Click "New Endpoint"**
3. **Configure endpoint:**
   - **Name:** `snaplook-yolos-gpu`
   - **GPU Type:** Select "RTX 3070" or "RTX 4090" (fastest)
   - **Container Image:** `your-dockerhub-username/snaplook-yolos:latest`
   - **Docker Command:** Leave empty (uses CMD from Dockerfile)
   - **Container Disk:** 10 GB minimum
   - **Workers:** Start with 1 (scales automatically)
   - **Max Workers:** 3-5 (adjust based on traffic)
   - **Idle Timeout:** 30 seconds (default)

4. **Advanced Settings:**
   - **GPU Memory:** Leave default
   - **Environment Variables:** None needed (model loads from cache)

5. **Click "Deploy"**

---

## Step 4: Get API Credentials

After deployment completes:

1. **Copy Endpoint ID** - Looks like: `abc123def456ghi789`
2. **Go to Settings** → https://www.runpod.io/console/user/settings
3. **Generate API Key** → Click "API Keys" → "Create API Key"
4. **Copy the key** - Starts with `runpod_api_...`

---

## Step 5: Configure Render Environment

In Render Dashboard, add these environment variables:

```
USE_RUNPOD=true
RUNPOD_API_KEY=runpod_api_xxxxxxxxxxxxx
RUNPOD_ENDPOINT_ID=abc123def456ghi789
```

Or update `render.yaml`:

```yaml
- key: USE_RUNPOD
  value: "true"
- key: RUNPOD_API_KEY
  sync: false  # Keep secret
- key: RUNPOD_ENDPOINT_ID
  value: "abc123def456ghi789"
```

---

## Step 6: Deploy and Test

1. **Commit changes:**
   ```bash
   git add server/fashion_detector_server.py render.yaml
   git commit -m "Add RunPod GPU support for 10x faster detection"
   git push
   ```

2. **Wait for Render deployment** (2-3 minutes)

3. **Test detection** - Should see in logs:
   ```
   [PERF] Using RunPod GPU serverless...
   [PERF] RunPod GPU inference: 0.7s (includes network latency)
   ```

---

## Expected Performance

**Before (CPU):**
- Detection: 5-8 seconds
- Total pipeline: 11-13 seconds

**After (RunPod GPU):**
- Detection: **0.3-0.7 seconds** (10x faster!)
- Total pipeline: **6-8 seconds** (40-50% faster overall)

**Note:** First request might be slower (~2-3s) due to cold start. Subsequent requests are fast.

---

## Troubleshooting

### Error: "RunPod detection failed: ..."

**Check logs for specific error:**

1. **"Authentication failed"**
   - Verify `RUNPOD_API_KEY` is correct
   - Key should start with `runpod_api_`

2. **"Endpoint not found"**
   - Verify `RUNPOD_ENDPOINT_ID` matches your endpoint
   - Check endpoint is deployed (not paused)

3. **"Timeout"**
   - First request can take 10-20s (cold start)
   - Increase timeout in code if needed
   - Check RunPod endpoint logs

4. **Falls back to local CPU**
   - Server automatically falls back to local if RunPod fails
   - Check logs for fallback reason

### Slow Performance

1. **Cold starts:**
   - First request after idle period is slow
   - RunPod loads model from disk
   - Enable "Keep Warm" (costs more) to avoid cold starts

2. **Network latency:**
   - RunPod adds 100-300ms network overhead
   - Still 10x faster overall than local CPU

### High Costs

1. **Check idle timeout:**
   - Set to 30s to minimize idle billing
   - Workers shut down when not in use

2. **Reduce max workers:**
   - Start with 1-2 workers
   - Scale up only if needed

3. **Monitor usage:**
   - RunPod Dashboard → Analytics
   - See requests per day and costs

---

## How to Disable RunPod

**Option 1: Environment variable** (instant)
```
USE_RUNPOD=false
```
Redeploy - falls back to local CPU immediately

**Option 2: Remove environment variables**
```
Delete RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID
```
Server auto-falls back to local

**Option 3: Pause RunPod endpoint**
- Go to RunPod Dashboard
- Click endpoint → "Pause"
- Stops billing, server falls back to local

---

## Cost Comparison

**Current (Render Standard $25/mo):**
- 5s detection time
- 2 concurrent workers
- **Total: $25/mo**

**With RunPod Serverless:**
- 0.5s detection time (10x faster!)
- Pay per request: ~$0.0003 per analysis
- **100 requests/day = ~$9/mo**
- **500 requests/day = ~$45/mo**
- **Total: $25 (Render) + $9-45 (RunPod) = $34-70/mo**

**With RunPod 24/7:**
- 0.5s detection time
- Always-on (no cold starts)
- **$180/mo RunPod + $25 Render = $205/mo**

**Recommendation:** Start with serverless, upgrade to 24/7 only if you have constant high traffic.

---

## Questions?

- RunPod docs: https://docs.runpod.io/serverless/overview
- Support: https://discord.gg/runpod
- Billing: RunPod Dashboard → Billing
