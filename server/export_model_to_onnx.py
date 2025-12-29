"""
Export YOLOS model to ONNX format for faster inference.

Run this script once to create the ONNX model file:
    python export_model_to_onnx.py

This creates 'yolos_fashionpedia.onnx' in the server directory.
"""

import torch
from transformers import YolosForObjectDetection, AutoImageProcessor
from PIL import Image
import numpy as np

MODEL_ID = "valentinafeve/yolos-fashionpedia"

def export_to_onnx():
    print("[ONNX EXPORT] Loading PyTorch model...")
    model = YolosForObjectDetection.from_pretrained(MODEL_ID)
    model.eval()

    processor = AutoImageProcessor.from_pretrained(MODEL_ID)

    print("[ONNX EXPORT] Creating dummy input for export...")
    # Create a dummy image for tracing
    dummy_image = Image.new('RGB', (800, 600), color='white')
    inputs = processor(images=dummy_image, return_tensors="pt")

    print("[ONNX EXPORT] Exporting to ONNX format...")
    torch.onnx.export(
        model,
        (inputs['pixel_values'],),
        "yolos_fashionpedia.onnx",
        input_names=['pixel_values'],
        output_names=['logits', 'pred_boxes'],
        dynamic_axes={
            'pixel_values': {0: 'batch_size', 2: 'height', 3: 'width'},
            'logits': {0: 'batch_size'},
            'pred_boxes': {0: 'batch_size'}
        },
        opset_version=14,
        do_constant_folding=True
    )

    print("[ONNX EXPORT] Export complete: yolos_fashionpedia.onnx")
    print("[ONNX EXPORT] Verifying ONNX model...")

    # Verify the exported model works
    import onnxruntime as ort

    session = ort.InferenceSession("yolos_fashionpedia.onnx", providers=['CPUExecutionProvider'])

    # Test inference
    onnx_inputs = {session.get_inputs()[0].name: inputs['pixel_values'].numpy()}
    outputs = session.run(None, onnx_inputs)

    print(f"[ONNX EXPORT] Verification successful!")
    print(f"[ONNX EXPORT] Output shapes: logits={outputs[0].shape}, pred_boxes={outputs[1].shape}")
    print(f"[ONNX EXPORT] Model ready to use!")

if __name__ == "__main__":
    export_to_onnx()
