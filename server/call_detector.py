# server/call_detector.py
import base64, json, requests, sys

image_path = sys.argv[1]
with open(image_path, "rb") as f:
    payload = {
        "image_base64": base64.b64encode(f.read()).decode("utf-8"),
        "imbb_api_key": "d7e1d857e4498c2e28acaa8d943ccea8",  # or leave out if env var set
        "max_crops": 4,
        "threshold": 0.2,
        "expand_ratio": 0.1,
    }

resp = requests.post("http://127.0.0.1:8000/detect", json=payload, timeout=60)
resp.raise_for_status()
print(json.dumps(resp.json(), indent=2))
