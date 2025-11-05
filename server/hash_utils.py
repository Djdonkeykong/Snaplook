"""
Image hashing utilities for duplicate detection.
Uses SHA256 for content-based hashing.
"""

import hashlib
from PIL import Image
import io
from typing import Union, Optional


def hash_image(image: Union[Image.Image, bytes]) -> str:
    """
    Generate SHA256 hash of image content.

    Args:
        image: PIL Image or bytes

    Returns:
        SHA256 hash as hex string
    """
    try:
        if isinstance(image, Image.Image):
            # Convert PIL Image to bytes
            buffer = io.BytesIO()
            image.save(buffer, format='JPEG')
            image_bytes = buffer.getvalue()
        else:
            # Already bytes
            image_bytes = image

        # Generate SHA256 hash
        hash_obj = hashlib.sha256(image_bytes)
        return hash_obj.hexdigest()

    except Exception as e:
        print(f"Image hashing error: {e}")
        return ""


def hash_url(url: str) -> str:
    """
    Generate hash of URL string.
    Useful for quick cache lookups.
    """
    return hashlib.sha256(url.encode()).hexdigest()


def normalize_url(url: str) -> str:
    """
    Normalize URL for consistent cache keys.
    Removes query parameters and fragments.
    """
    try:
        from urllib.parse import urlparse, urlunparse

        parsed = urlparse(url)
        # Keep only scheme, netloc, and path (remove query/fragment)
        normalized = urlunparse((
            parsed.scheme,
            parsed.netloc,
            parsed.path,
            '',  # params
            '',  # query
            ''   # fragment
        ))
        return normalized
    except:
        return url
