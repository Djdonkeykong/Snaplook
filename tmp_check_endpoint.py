import base64
import requests
from pathlib import Path
path = Path(r"assets/images/pinterest_tutorial.jpg")
with path.open("rb") as f:
    image_b64 = base64.b64encode(f.read()).decode("utf-8")
payload = {
    "user_id": "test-user-id",
    "image_base64": image_b64,
    "search_type": "photos"
}
resp = requests.post("https://1b62144139a8.ngrok-free.app/api/v1/analyze", json=payload, timeout=120)
print("status:", resp.status_code)
print("body:", resp.text[:500])
