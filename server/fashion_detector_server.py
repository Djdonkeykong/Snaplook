import io
import sys
import os  # ✅ needed for environment variables
import json
import base64
import time
import torch
import requests
from pathlib import Path
from datetime import datetime
from typing import Optional, List
from concurrent.futures import ThreadPoolExecutor, as_completed  # ✅ parallel uploads

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from PIL import Image, ImageDraw
from transformers import AutoImageProcessor, YolosForObjectDetection

# === CONFIG ===
MODEL_ID = "valentinafeve/yolos-fashionpedia"
CONF_THRESHOLD = float(os.getenv("CONF_THRESHOLD", 0.275))
EXPAND_RATIO = float(os.getenv("EXPAND_RATIO", 0.1))
MAX_GARMENTS = int(os.getenv("MAX_GARMENTS", 4))
UPLOAD_TO_IMGBB = True

# Tiny/irrelevant crop guard (pixels)
MIN_CROP_W = 80
MIN_CROP_H = 80
MIN_CROP_AREA = 120 * 120  # extra safety

# === CATEGORIES ===
MAJOR_GARMENTS = {
    "shirt, blouse", "top, t-shirt, sweatshirt", "sweater", "cardigan",
    "jacket", "vest", "coat", "dress", "jumpsuit", "cape",
    "pants", "shorts", "skirt",
    "shoe", "bag, wallet", "glasses", "hat",
    "headband, head covering, hair accessory", "scarf"
}

OUTERWEAR = {"coat", "jacket", "dress", "cape", "vest"}
ACCESSORIES = {"shoe", "bag, wallet", "glasses"}

# NEW: treat overlapping uppers as the same garment when they collide
UPPER_GARMENTS = {
    "shirt, blouse",
    "top, t-shirt, sweatshirt",
    "sweater",
    "cardigan",
}
UPPER_IOU_MERGE = 0.35          # area IoU to consider same
UPPER_OVERLAP_MERGE = 0.60      # inner-overlap fraction to consider same
UPPER_CENTER_DIST_FRAC = 0.30   # centers closer than ~30% of avg width → same region

# Slightly promote bottoms so we keep 1 upper + 1 lower when ties happen
CATEGORY_PRIORITY = {
    "coat": 5, "jacket": 5, "dress": 5,
    "vest": 4, "cardigan": 4, "sweater": 4,
    "shirt, blouse": 4, "top, t-shirt, sweatshirt": 4,
    "pants": 4, "skirt": 4, "shorts": 4,  # ⬅ raised from 3
    "shoe": 3, "bag, wallet": 3, "glasses": 2, "hat": 2, "headband, head covering, hair accessory": 1,
    "scarf": 1,
}

# === Serp relevance hints (returned to the client) ===
BANNED_TERMS = {
    "texture", "pattern", "drawing", "clipart", "illustration",
    "lace", "shoelace", "buttons", "fabric", "cloth", "hanger",
    "cartoon", "design template", "icon", "logo", "silhouette",
    "vector", "png", "mockup", "stencil", "svg", "ai generated"
}

CATEGORY_KEYWORDS = {
    "shoe": {"shoe", "sneaker", "boot", "heel", "heels", "sandal", "footwear", "loafer", "trainer"},
    "dress": {"dress", "gown", "outfit"},
    "pants": {"pants", "trousers", "jeans", "slacks"},
    "skirt": {"skirt"},
    "shorts": {"shorts"},
    "coat": {"coat", "jacket", "outerwear", "parka", "trench"},
    "jacket": {"jacket", "blazer"},
    "top, t-shirt, sweatshirt": {"t-shirt", "tee", "top", "sweatshirt", "hoodie"},
    "shirt, blouse": {"shirt", "blouse", "button-down"},
    "sweater": {"sweater", "knit", "pullover", "cardigan"},
    "bag, wallet": {"bag", "purse", "handbag", "tote", "wallet", "backpack", "crossbody"},
    "glasses": {"glasses", "sunglasses", "eyewear"},
    "hat": {"hat", "beanie", "cap", "beret", "bucket hat"},
}

# === FASTAPI SETUP ===
app = FastAPI(title="Fashion Detector API")

# === MODELS ===
print("🔄 Loading YOLOS model...")
processor = AutoImageProcessor.from_pretrained(MODEL_ID)
model = YolosForObjectDetection.from_pretrained(MODEL_ID)
print("✅ Model loaded.")

# === INPUT SCHEMA ===
class DetectRequest(BaseModel):
    image_base64: str
    imbb_api_key: Optional[str] = None
    threshold: Optional[float] = Field(default_factory=lambda: CONF_THRESHOLD)
    expand_ratio: Optional[float] = Field(default=EXPAND_RATIO)
    max_crops: Optional[int] = Field(default=MAX_GARMENTS)

# === HELPERS ===
def expand_bbox(bbox, img_width, img_height, ratio=0.1):
    x1, y1, x2, y2 = bbox
    w, h = x2 - x1, y2 - y1
    expand_w, expand_h = w * ratio, h * ratio
    x1 = max(0, x1 - expand_w)
    y1 = max(0, y1 - expand_h)
    x2 = min(img_width, x2 + expand_w)
    y2 = min(img_height, y2 + expand_h)
    return [int(x1), int(y1), int(x2), int(y2)]

def bbox_iou(box1, box2):
    x1, y1, x2, y2 = box1
    x1b, y1b, x2b, y2b = box2
    xi1, yi1 = max(x1, x1b), max(y1, y1b)
    xi2, yi2 = min(x2, x2b), min(y2, y2b)
    inter = max(0, xi2 - xi1) * max(0, yi2 - yi1)
    if inter == 0:
        return 0.0
    a1 = (x2 - x1) * (y2 - y1)
    a2 = (x2b - x1b) * (y2b - y1b)
    return inter / (a1 + a2 - inter)

def center_distance(box1, box2):
    x1, y1, x2, y2 = box1
    X1, Y1, X2, Y2 = box2
    cx1, cy1 = (x1 + x2) / 2, (y1 + y2) / 2
    cx2, cy2 = (X1 + X2) / 2, (Y1 + Y2) / 2
    return ((cx1 - cx2) ** 2 + (cy1 - cy2) ** 2) ** 0.5

def contains_tolerant(inner, outer, tol=5):
    x1, y1, x2, y2 = inner
    X1, Y1, X2, Y2 = outer
    return x1 >= X1 - tol and y1 >= Y1 - tol and x2 <= X2 + tol and y2 <= Y2 + tol

def overlap_ratio(inner, outer):
    x1, y1, x2, y2 = inner
    X1, Y1, X2, Y2 = outer
    xi1, yi1 = max(x1, X1), max(y1, Y1)
    xi2, yi2 = min(x2, X2), min(y2, Y2)
    inter_area = max(0, xi2 - xi1) * max(0, yi2 - yi1)
    if inter_area == 0:
        return 0.0
    inner_area = (x2 - x1) * (y2 - y1)
    return inter_area / inner_area

# === RELIABLE & FAST IMG UPLOAD ===
def upload_to_imgbb(image: Image.Image, api_key: str) -> Optional[str]:
    """Upload image to ImgBB with compression, retry, and smart size filtering."""
    image = image.convert("RGB")
    w, h = image.size
    if w < MIN_CROP_W or h < MIN_CROP_H or (w * h) < MIN_CROP_AREA:
        print(f"⚠️ Skipping tiny/insignificant crop {w}x{h}")
        return None

    for attempt in range(1, 4):
        try:
            buf = io.BytesIO()
            # High quality first, reduce on retries
            quality = 95 if attempt == 1 else 85 - (attempt - 2) * 10  # 95, 85, 75
            image.save(buf, format="JPEG", quality=quality, optimize=True)
            b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

            r = requests.post(
                "https://api.imgbb.com/1/upload",
                data={"key": api_key, "image": b64},
                timeout=12,
            )

            if r.status_code == 200:
                data = r.json()
                if data.get("success") and "data" in data:
                    url = data["data"].get("url")
                    # ImgBB sometimes returns blue PNG placeholder for truncated uploads
                    if url and not url.endswith(".png"):
                        print(f"☁️ ImgBB upload succeeded (attempt {attempt}): {url}")
                        return url

            print(f"⚠️ ImgBB upload failed (attempt {attempt}): {r.status_code}")
        except Exception as e:
            print(f"❌ ImgBB error (attempt {attempt}): {e}")

        time.sleep(1)

    print("🚫 All ImgBB upload attempts failed.")
    return None

# === DETECTION CORE ===
def run_detection(image: Image.Image, threshold: float, expand_ratio: float, max_crops: int):
    print(f"🚦 Using detection threshold: {threshold}")
    inputs = processor(images=image, return_tensors="pt")
    with torch.no_grad():
        outputs = model(**inputs)
    results = processor.post_process_object_detection(
        outputs,
        threshold=threshold,
        target_sizes=torch.tensor([[image.height, image.width]])
    )[0]

    # === Collect detections ===
    detections = []
    for box, score, label_idx in zip(results["boxes"], results["scores"], results["labels"]):
        score = score.item()
        label = model.config.id2label[label_idx.item()]
        if label not in MAJOR_GARMENTS or score < threshold:
            continue
        x1, y1, x2, y2 = map(int, box.tolist())
        detections.append({"label": label, "score": score, "bbox": [x1, y1, x2, y2]})

    # === Smart Headwear False Positive Filter (v3) ===
    filtered_detections = []
    for det in detections:
        label = det["label"]
        x1, y1, x2, y2 = det["bbox"]
        w, h = x2 - x1, y2 - y1
        rel_w = w / image.width
        rel_h = h / image.height
        rel_y1 = y1 / image.height
        rel_y2 = y2 / image.height
        aspect_ratio = w / (h + 1e-5)

        if label in {"hat", "headband, head covering, hair accessory"}:
            if rel_w > 0.40 or rel_h > 0.35:
                print(f"🧢 Skipping oversized headwear (likely hair/head): bbox=({x1},{y1},{x2},{y2})")
                continue
            if rel_y1 > 0.25 or rel_y2 > 0.60:
                print(f"🧢 Skipping low-position headwear: bbox=({x1},{y1},{x2},{y2})")
                continue
            if aspect_ratio > 2.5 or aspect_ratio < 0.4:
                print(f"🧢 Skipping abnormal aspect headwear (likely hair): bbox=({x1},{y1},{x2},{y2})")
                continue
            has_upper_garment = any(
                g["label"] in {"shirt, blouse", "top, t-shirt, sweatshirt", "sweater", "coat", "jacket", "dress"}
                for g in detections
            )
            if not has_upper_garment:
                print("🧢 Skipping headwear (no upper garment context).")
                continue
            if det["score"] < 0.515:
                print(f"🧢 Skipping weak headwear (score {det['score']:.3f}).")
                continue

        # === Smart Pants Filter ===
        if label == "pants" and rel_h < 0.20:
            print(f"👖 Skipping too-small pants (height {rel_h:.2f}) — likely false positive.")
            continue

        filtered_detections.append(det)

    detections = filtered_detections

    # === Sort detections ===
    detections = sorted(
        detections,
        key=lambda d: (CATEGORY_PRIORITY.get(d["label"], 0), d["score"]),
        reverse=True,
    )

    print(f"✨ Found {len(detections)} initial garment candidates:")
    for d in detections:
        x1, y1, x2, y2 = d["bbox"]
        print(f"   - {d['label']} ({d['score']:.3f}) bbox=({x1},{y1},{x2},{y2})")

    # === Smart Containment Filtering (v5) ===
    filtered = []
    for det in detections:
        keep = True
        for kept in filtered:
            iou = bbox_iou(det["bbox"], kept["bbox"])
            overlap_inner = overlap_ratio(det["bbox"], kept["bbox"])

            # Merge jacket & coat if overlapping
            if {det["label"], kept["label"]} <= {"jacket", "coat"} and (iou > 0.5 or overlap_inner > 0.6):
                stronger = det if det["score"] >= kept["score"] else kept
                weaker = kept if stronger is det else det
                print(f"🧥 Merging outerwear: keeping '{stronger['label']}' ({stronger['score']:.3f}), dropping '{weaker['label']}'")
                if stronger is det:
                    filtered.remove(kept)
                    break
                else:
                    keep = False
                    break

            # NEW: Merge overlapping UPPER garments (e.g., shirt/blouse vs top/tee/sweatshirt vs sweater/cardigan)
            if det["label"] in UPPER_GARMENTS and kept["label"] in UPPER_GARMENTS:
                cdist = center_distance(det["bbox"], kept["bbox"])
                avg_w = ((det["bbox"][2] - det["bbox"][0]) + (kept["bbox"][2] - kept["bbox"][0])) / 2
                centers_close = cdist < UPPER_CENTER_DIST_FRAC * max(1.0, avg_w)
                if centers_close or iou > UPPER_IOU_MERGE or overlap_inner > UPPER_OVERLAP_MERGE:
                    stronger = det if det["score"] >= kept["score"] else kept
                    weaker = kept if stronger is det else det
                    print(f"👕 Merging uppers: keeping '{stronger['label']}' ({stronger['score']:.3f}), dropping '{weaker['label']}'")
                    if stronger is det:
                        filtered.remove(kept)
                        break  # re-evaluate det against remaining
                    else:
                        keep = False
                        break

            # Suppress inner garments under long outerwear
            if kept["label"] in OUTERWEAR and det["label"] not in OUTERWEAR:
                if overlap_inner > 0.7:
                    print(f"🧥 Suppressing inner '{det['label']}' under '{kept['label']}' ({overlap_inner:.2f})")
                    keep = False
                    break

            # Handle accessory overlap gently
            if kept["label"] in OUTERWEAR and det["label"] in ACCESSORIES:
                _, y1, _, y2 = det["bbox"]
                rel_y_center = (y1 + y2) / (2 * image.height)
                if rel_y_center > 0.35:
                    continue

        if keep:
            filtered.append(det)

    # === Smart Pants Suppression under Long Outerwear ===
    long_outerwear = [
        d for d in filtered
        if d["label"] in {"coat", "jacket", "dress"} and (d["bbox"][3] / image.height) > 0.7
    ]
    if long_outerwear:
        new_filtered = []
        for det in filtered:
            if det["label"] == "pants":
                covered = False
                for outer in long_outerwear:
                    overlap = overlap_ratio(det["bbox"], outer["bbox"])
                    if overlap > 0.6 and outer["score"] > 0.5:
                        print(f"👖 Suppressing pants under long '{outer['label']}' (overlap={overlap:.2f})")
                        covered = True
                        break
                if not covered:
                    new_filtered.append(det)
            else:
                new_filtered.append(det)
        filtered = new_filtered

    # === Shoe Merge, Accessory, Deduplication ===
    shoes = [d for d in filtered if d["label"] == "shoe"]
    if len(shoes) > 1:
        merged, used = [], set()
        for i, s1 in enumerate(shoes):
            if i in used:
                continue
            for j, s2 in enumerate(shoes[i + 1:], start=i + 1):
                if j in used:
                    continue
                iou = bbox_iou(s1["bbox"], s2["bbox"])
                dist = center_distance(s1["bbox"], s2["bbox"])
                avg_w = ((s1["bbox"][2] - s1["bbox"][0]) + (s2["bbox"][2] - s2["bbox"][0])) / 2
                if iou > 0.1 or dist < 0.3 * avg_w:
                    x1 = min(s1["bbox"][0], s2["bbox"][0])
                    y1 = min(s1["bbox"][1], s2["bbox"][1])
                    x2 = max(s1["bbox"][2], s2["bbox"][2])
                    y2 = max(s1["bbox"][3], s2["bbox"][3])
                    merged.append({
                        "label": "shoe",
                        "score": max(s1["score"], s2["score"]),
                        "bbox": [x1, y1, x2, y2]
                    })
                    used.update({i, j})
                    break
            if i not in used:
                merged.append(s1)
        filtered = [d for d in filtered if d["label"] != "shoe"] + merged

    # Accessory fallback
    if not any(d["label"] in ACCESSORIES for d in filtered):
        acc = [d for d in detections if d["label"] in ACCESSORIES]
        if acc:
            best = max(acc, key=lambda d: d["score"])
            filtered.append(best)
            print(f"🎒 Added accessory '{best['label']}' to ensure coverage.")

    # Deduplication by label (keep strongest), but preserve best shoe
    deduped = {}
    for det in filtered:
        label = det["label"]
        if label not in deduped or det["score"] > deduped[label]["score"]:
            deduped[label] = det

    if "shoe" in deduped:
        best_shoe = deduped["shoe"]
        deduped = {k: v for k, v in deduped.items() if k != "shoe"}
        deduped["shoe"] = best_shoe

    filtered = list(deduped.values())

    # Sort + limit
    filtered = sorted(
        filtered,
        key=lambda d: (CATEGORY_PRIORITY.get(d["label"], 0), d["score"]),
        reverse=True,
    )[:max_crops]

    for i, det in enumerate(filtered):
        det["id"] = f"garment_{i + 1}"

    print("🧩 Final kept garments:")
    for d in filtered:
        x1, y1, x2, y2 = d["bbox"]
        print(f"   • {d['label']} ({d['score']:.3f}) bbox=({x1},{y1},{x2},{y2})")

    print(f"🧠 Summary: {', '.join(d['label'] for d in filtered)}")
    print(f"🧹 After hierarchical filtering: {len(filtered)} garments kept.")
    return filtered

# === MAIN ENDPOINT (Optimized for Speed) ===
@app.post("/detect")
def detect(req: DetectRequest):
    try:
        img_bytes = base64.b64decode(req.image_base64)
        image = Image.open(io.BytesIO(img_bytes)).convert("RGB")

        # Step 1 — Run YOLOS detection
        filtered = run_detection(image, req.threshold, req.expand_ratio, req.max_crops)

        # Step 2 — Prepare crops
        crops = []
        for det in filtered:
            x1, y1, x2, y2 = expand_bbox(det["bbox"], image.width, image.height, req.expand_ratio)
            crop = image.crop((x1, y1, x2, y2))
            crops.append((det, crop, [x1, y1, x2, y2]))

        # Step 3 — Parallel ImgBB uploads
        results = []
        if UPLOAD_TO_IMGBB and req.imbb_api_key and len(crops) > 0:
            print(f"☁️ Uploading {len(crops)} crops to ImgBB in parallel...")
            with ThreadPoolExecutor(max_workers=min(4, len(crops))) as executor:
                future_to_item = {
                    executor.submit(upload_to_imgbb, crop, req.imbb_api_key): (det, bbox)
                    for det, crop, bbox in crops
                }
                for future in as_completed(future_to_item):
                    det, bbox = future_to_item[future]
                    upload_url = None
                    try:
                        upload_url = future.result(timeout=25)
                    except Exception as e:
                        print(f"⚠️ Upload failed for {det['label']}: {e}")

                    results.append({
                        "id": det["id"],
                        "label": det["label"],
                        "score": round(det["score"], 3),
                        "bbox": bbox,
                        "imgbb_url": upload_url,
                    })
        else:
            # If uploads are disabled or no key provided
            for det, crop, bbox in crops:
                results.append({
                    "id": det["id"],
                    "label": det["label"],
                    "score": round(det["score"], 3),
                    "bbox": bbox,
                    "imgbb_url": None,
                })

        print(f"✅ Detection complete. {len(results)} garments processed.")
        return {
            "count": len(results),
            "results": results,
            # Helps the client filter SerpAPI results more aggressively
            "relevance_hints": {
                "banned_terms": sorted(BANNED_TERMS),
                "category_keywords": {k: sorted(list(v)) for k, v in CATEGORY_KEYWORDS.items()}
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# === DEBUG ENDPOINT ===
@app.post("/debug")
def debug_detect(req: DetectRequest):
    img_bytes = base64.b64decode(req.image_base64)
    image = Image.open(io.BytesIO(img_bytes)).convert("RGB")

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    out_dir = Path(f"./debug_{timestamp}")
    out_dir.mkdir(parents=True, exist_ok=True)

    filtered = run_detection(image, req.threshold, req.expand_ratio, req.max_crops)

    debug_image = image.copy()
    draw = ImageDraw.Draw(debug_image)
    cropped_items = []

    for i, det in enumerate(filtered):
        x1, y1, x2, y2 = expand_bbox(det["bbox"], image.width, image.height, req.expand_ratio)
        label, score = det["label"], det["score"]
        draw.rectangle((x1, y1, x2, y2), outline="red", width=3)
        draw.text((x1 + 4, y1 + 4), f"{label}:{score:.2f}", fill="red")
        crop = image.crop((x1, y1, x2, y2))
        crop_path = out_dir / f"debug_{i + 1:02d}_{label}_{score:.2f}.jpg"
        crop.save(crop_path)
        cropped_items.append({
            "file": str(crop_path),
            "label": label,
            "score": round(score, 3),
            "bbox": [x1, y1, x2, y2]
        })
        print(f"✅ Saved crop: {str(crop_path.name)}")

    debug_img_path = out_dir / "debug_boxes.jpg"
    debug_image.save(debug_img_path)
    json_path = out_dir / "debug_results.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(cropped_items, f, indent=2, ensure_ascii=False)

    return {
        "message": "Debug detection complete",
        "debug_folder": str(out_dir),
        "results": cropped_items
    }

# === ROOT ===
@app.get("/")
def root():
    return {"message": "Fashion Detector API is running!"}
