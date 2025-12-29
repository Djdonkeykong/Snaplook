FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel

# Install dependencies
COPY requirements_runpod.txt .
RUN pip install --no-cache-dir -r requirements_runpod.txt

# Copy handler code
COPY runpod_handler.py /app/runpod_handler.py

WORKDIR /app

# Pre-download model at build time to speed up cold starts
RUN python -c "from transformers import AutoImageProcessor, YolosForObjectDetection; \
    AutoImageProcessor.from_pretrained('valentinafeve/yolos-fashionpedia'); \
    YolosForObjectDetection.from_pretrained('valentinafeve/yolos-fashionpedia')"

# RunPod serverless handler
CMD ["python", "-u", "runpod_handler.py"]
