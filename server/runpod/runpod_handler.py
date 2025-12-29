import runpod
import torch
import base64
import io
from PIL import Image
from transformers import AutoImageProcessor, YolosForObjectDetection

MODEL_ID = "valentinafeve/yolos-fashionpedia"

# Major garments to detect (same as server)
MAJOR_GARMENTS = {
    "shirt, blouse", "top, t-shirt, sweatshirt", "sweater", "cardigan",
    "jacket", "vest", "pants", "shorts", "skirt", "coat", "dress",
    "jumpsuit", "cape", "glasses", "hat", "headband, head covering, hair accessory",
    "tie", "glove", "watch", "belt", "leg warmer", "tights, stockings",
    "sock", "shoe", "bag, wallet", "scarf", "umbrella", "hood", "collar",
    "lapel", "epaulette", "sleeve", "pocket", "neckline", "buckle",
    "zipper", "applique", "bead", "bow", "flower", "fringe", "ribbon",
    "rivet", "ruffle", "sequin", "tassel"
}

# Load model once at startup (cached across requests)
print("[RunPod] Loading YOLOS model...")
processor = AutoImageProcessor.from_pretrained(MODEL_ID)
model = YolosForObjectDetection.from_pretrained(MODEL_ID)
model.eval()

# Move to GPU if available
device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)
print(f"[RunPod] Model loaded on {device}")


def handler(job):
    """
    RunPod serverless handler for YOLOS detection.

    Input:
    {
        "input": {
            "image_base64": "...",
            "threshold": 0.275
        }
    }

    Output:
    {
        "detections": [
            {"label": "dress", "score": 0.95, "bbox": [x1, y1, x2, y2]},
            ...
        ]
    }
    """
    job_input = job['input']

    # Parse input
    image_base64 = job_input.get('image_base64')
    threshold = job_input.get('threshold', 0.275)

    if not image_base64:
        return {"error": "image_base64 is required"}

    try:
        # Decode image
        image_data = base64.b64decode(image_base64)
        image = Image.open(io.BytesIO(image_data))
        if image.mode != 'RGB':
            image = image.convert('RGB')

        # Run detection
        inputs = processor(images=image, return_tensors="pt")

        # Move inputs to GPU
        inputs = {k: v.to(device) for k, v in inputs.items()}

        with torch.no_grad():
            outputs = model(**inputs)

        # Post-process
        target_sizes = torch.tensor([[image.height, image.width]]).to(device)
        results = processor.post_process_object_detection(
            outputs,
            threshold=threshold,
            target_sizes=target_sizes
        )[0]

        # Format detections
        detections = []
        for box, score, label_idx in zip(results["boxes"], results["scores"], results["labels"]):
            score_val = score.item()
            label = model.config.id2label[label_idx.item()]

            # Filter by garment type and threshold
            if label not in MAJOR_GARMENTS or score_val < threshold:
                continue

            x1, y1, x2, y2 = map(int, box.tolist())
            detections.append({
                "label": label,
                "score": score_val,
                "bbox": [x1, y1, x2, y2]
            })

        return {
            "detections": detections,
            "image_size": {"width": image.width, "height": image.height}
        }

    except Exception as e:
        return {"error": str(e)}


# Start RunPod serverless
runpod.serverless.start({"handler": handler})
