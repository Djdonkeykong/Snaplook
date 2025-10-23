#!/usr/bin/env python3
"""
Seed the Supabase `products` table with high-quality fashion inspiration images
fetched via SerpAPI's Google Images endpoint. Only metadata is stored – the app
continues to load the actual images from their original hosts.

Enhanced version: supports full SerpAPI parameters like location, aspect ratio,
image color/type, date filtering, etc.

Usage example:
    python scripts/seed_serp_products.py \
        --queries "fashion women's clothing" \
        --pages 1 --per-page 50 \
        --img-size large --location "United States" \
        --aspect-ratio tall --type photo

Environment variables:
    SERPAPI_API_KEY
    SUPABASE_URL
    SUPABASE_ANON_KEY
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from dataclasses import dataclass
from typing import Iterable, List, Optional
from urllib.parse import quote_plus, urlparse

import requests

# Constants
SERP_ENDPOINT = "https://serpapi.com/search.json"
MIN_IMAGE_DIMENSION = int(os.getenv("SERPAPI_MIN_DIMENSION", "800"))
DEFAULT_IMAGE_SIZE = os.getenv("SERPAPI_IMAGE_SIZE", "xxlarge")
SUPPORTED_IMAGE_SIZES = ["xxlarge", "xlarge", "large", "medium"]
IMAGE_SIZE_CHOICES = SUPPORTED_IMAGE_SIZES + ["none"]

DEFAULT_QUERIES = [
    "gucci handbag",
]



# ------------------------- Errors -------------------------

class SerpApiError(RuntimeError):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(f"SerpAPI error {status}: {message}")
        self.status = status
        self.message = message

    @property
    def is_image_size_error(self) -> bool:
        if self.status != 400:
            return False
        text = self.message.lower()
        return "unsupported" in text and "imgsz" in text


# ------------------------- Environment Helpers -------------------------

def load_env_value(key: str) -> Optional[str]:
    value = os.getenv(key)
    if value:
        return value

    env_path = os.path.join(os.getcwd(), ".env")
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as handle:
            for line in handle:
                if not line or "=" not in line:
                    continue
                name, maybe_value = line.strip().split("=", 1)
                if name == key:
                    return maybe_value
    return None


def ensure_env(key: str) -> str:
    value = load_env_value(key)
    if not value:
        raise SystemExit(f"Missing required environment variable: {key}")
    return value


# ------------------------- Data Model -------------------------

@dataclass
class ProductMetadata:
    id: int
    title: str
    image_url: str
    landing_url: str
    source: str
    query: str
    width: Optional[int]
    height: Optional[int]
    thumbnail_url: Optional[str]

    def to_supabase_payload(self) -> dict:
        description_parts: List[str] = []
        if self.width and self.height:
            description_parts.append(f"{self.width}×{self.height}px")
        description_parts.append(f"Imported via SerpAPI query: {self.query}")

        return {
            "id": self.id,
            "title": self.title[:200] if self.title else f"Inspiration – {self.query}",
            "image_url": self.image_url,
            "url": self.landing_url,
            "source": self.source,
            "category": "inspiration",
            "description": " | ".join(description_parts),
            "brand": self.source,
        }


# ------------------------- Supabase Client -------------------------

class SupabaseClient:
    def __init__(self, url: str, api_key: str) -> None:
        self.url = url.rstrip("/")
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update(
            {
                "apikey": api_key,
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            }
        )

    def _request(self, method: str, path: str, **kwargs) -> requests.Response:
        resp = self.session.request(method, f"{self.url}{path}", timeout=30, **kwargs)
        if resp.status_code >= 400:
            raise RuntimeError(f"Supabase error {resp.status_code}: {resp.text}")
        return resp

    def get_max_product_id(self) -> int:
        resp = self._request(
            "GET",
            "/rest/v1/products?select=id&order=id.desc&limit=1",
            headers={"Accept": "application/json"},
        )
        data = resp.json()
        return int(data[0]["id"]) if data else 0

    def product_exists(self, image_url: str) -> bool:
        encoded = quote_plus(image_url)
        resp = self._request(
            "GET",
            f"/rest/v1/products?select=id&image_url=eq.{encoded}&limit=1",
            headers={"Accept": "application/json"},
        )
        data = resp.json()
        return bool(data)

    def insert_products(self, products: Iterable[ProductMetadata]) -> int:
        payload = [p.to_supabase_payload() for p in products]
        if not payload:
            return 0
        resp = self._request(
            "POST",
            "/rest/v1/products",
            headers={"Prefer": "return=representation"},
            json=payload,
        )
        return len(resp.json())


# ------------------------- SerpAPI Fetch -------------------------

def fetch_serp_images(api_key: str, query: str, page: int, max_results: int, image_size: Optional[str], extra_params: dict) -> List[dict]:
    params = {
        "engine": "google_images",
        "q": query,
        "ijn": page,
        "api_key": api_key,
        "tbm": "isch",
        "safe": extra_params.get("safe", "active"),
        "gl": extra_params.get("country", "us"),
        "hl": extra_params.get("language", "en"),
        "num": max(10, min(max_results, 100)),
    }

    # Add optional parameters
    optional_keys = [
        "location", "uule", "google_domain", "cr", "tbs", "chips", "imgar",
        "imgcolor", "imgtype", "imglicense", "device", "no_cache", "filter", "nfpr"
    ]
    for key in optional_keys:
        if extra_params.get(key) is not None:
            params[key] = extra_params[key]

    if image_size:
        params["imgsz"] = image_size

    response = requests.get(SERP_ENDPOINT, params=params, timeout=60)
    if response.status_code == 429:
        raise SerpApiError(429, "rate limit hit (429). Try again later.")
    if response.status_code >= 400:
        raise SerpApiError(response.status_code, response.text)

    data = response.json()
    results = data.get("images_results") or data.get("image_results") or []
    return results[:max_results]


# ------------------------- Helpers -------------------------

def normalize_source(url: Optional[str], fallback: Optional[str]) -> str:
    if url:
        domain = urlparse(url).netloc
        if domain:
            return domain.lower()
    if fallback:
        return fallback.lower()
    return "unknown"


def filter_and_transform_results(results: Iterable[dict], query: str, seen_urls: set[str], next_id: int) -> List[ProductMetadata]:
    products: List[ProductMetadata] = []
    for result in results:
        original = result.get("original") or result.get("image")
        link = result.get("link") or result.get("source")
        if not original or not link or original in seen_urls:
            continue

        width = result.get("original_width") or result.get("width")
        height = result.get("original_height") or result.get("height")
        try:
            w, h = int(width), int(height)
            if w < MIN_IMAGE_DIMENSION or h < MIN_IMAGE_DIMENSION:
                continue
        except (ValueError, TypeError):
            w = h = None

        source = normalize_source(link, result.get("source"))
        title = result.get("title") or result.get("snippet") or result.get("description")

        metadata = ProductMetadata(
            id=next_id + len(products),
            title=title or f"Inspiration – {query}",
            image_url=original,
            landing_url=link,
            source=source,
            query=query,
            width=w,
            height=h,
            thumbnail_url=result.get("thumbnail"),
        )
        products.append(metadata)
        seen_urls.add(original)
    return products


# ------------------------- Main -------------------------

def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Seed Supabase products with SerpAPI image metadata.")
    parser.add_argument("--queries", nargs="+", default=DEFAULT_QUERIES)
    parser.add_argument("--pages", type=int, default=2)
    parser.add_argument("--per-page", type=int, default=40)
    parser.add_argument("--delay", type=float, default=2.5)
    parser.add_argument("--img-size", choices=IMAGE_SIZE_CHOICES, default="none")
    parser.add_argument("--location")
    parser.add_argument("--uule")
    parser.add_argument("--google-domain")
    parser.add_argument("--country", default="us")
    parser.add_argument("--language", default="en")
    parser.add_argument("--cr")
    parser.add_argument("--aspect-ratio", dest="imgar", choices=["tall", "square", "wide", "panoramic"])
    parser.add_argument("--color", dest="imgcolor", choices=["color", "blackandwhite", "transparent"])
    parser.add_argument("--type", dest="imgtype", choices=["photo", "clipart", "lineart", "animated"])
    parser.add_argument("--license", dest="imglicense")
    parser.add_argument("--safe", choices=["active", "off"], default="active")
    parser.add_argument("--tbs")
    parser.add_argument("--chips")
    parser.add_argument("--device")
    parser.add_argument("--no-cache", dest="no_cache", action="store_true")
    parser.add_argument("--nfpr", choices=["0", "1"])
    parser.add_argument("--filter", choices=["0", "1"])
    args = parser.parse_args(argv)

    serp_api_key = ensure_env("SERPAPI_API_KEY")
    supabase_url = ensure_env("SUPABASE_URL")
    supabase_key = ensure_env("SUPABASE_ANON_KEY")

    supabase = SupabaseClient(supabase_url, supabase_key)
    next_id = supabase.get_max_product_id() + 1
    print(f"[Init] Starting inserts at product id {next_id}")

    extra_params = {
        "location": args.location,
        "uule": args.uule,
        "google_domain": args.google_domain,
        "country": args.country,
        "language": args.language,
        "cr": args.cr,
        "imgar": args.imgar,
        "imgcolor": args.imgcolor,
        "imgtype": args.imgtype,
        "imglicense": args.imglicense,
        "safe": args.safe,
        "tbs": args.tbs,
        "chips": args.chips,
        "device": args.device,
        "no_cache": str(args.no_cache).lower() if args.no_cache else None,
        "filter": args.filter,
        "nfpr": args.nfpr,
    }

    total_inserted = 0
    total_skipped = 0
    seen_urls: set[str] = set()

    for query in args.queries:
        print(f"\n[Query] {query}")
        for page in range(args.pages):
            results: Optional[List[dict]] = None
            used_size = "none"
            last_error: Optional[SerpApiError] = None

            size_preferences: List[Optional[str]]
            if args.img_size == "none":
                size_preferences = [None]
            else:
                start_index = SUPPORTED_IMAGE_SIZES.index(args.img_size)
                size_preferences = SUPPORTED_IMAGE_SIZES[start_index:] + [None]

            for candidate_size in size_preferences:
                try:
                    results = fetch_serp_images(
                        serp_api_key,
                        query,
                        page,
                        args.per_page,
                        candidate_size,
                        extra_params,
                    )
                    used_size = candidate_size or "none"
                    if last_error and last_error.is_image_size_error:
                        print(
                            f"  [Info] imgsz fallback succeeded with '{used_size}'."
                        )
                    last_error = None
                    break
                except SerpApiError as exc:
                    last_error = exc
                    if exc.is_image_size_error and candidate_size is not None:
                        print(
                            f"  [Warn] imgsz '{candidate_size}' unsupported. Retrying with next size."
                        )
                        continue
                    print(f"  [Error] Failed to fetch page {page}: {exc}")
                    results = None
                    break

            if results is None:
                if last_error and not last_error.is_image_size_error:
                    continue
                print(
                    f"  [Error] Exhausted image size fallbacks for page {page} (query '{query}')."
                )
                continue

            print(
                f"  [Info] Retrieved {len(results)} results (page {page}, imgsz={used_size})"
            )
            transformed = filter_and_transform_results(results, query, seen_urls, next_id)

            fresh_records = [r for r in transformed if not supabase.product_exists(r.image_url)]
            for offset, record in enumerate(fresh_records):
                record.id = next_id + offset

            skipped = len(transformed) - len(fresh_records)
            total_skipped += skipped

            if not fresh_records:
                print("  [Info] No new records to insert.")
            else:
                inserted = supabase.insert_products(fresh_records)
                total_inserted += inserted
                next_id += inserted
                print(f"  [Success] Inserted {inserted} new products.")
            if skipped:
                print(f"  [Info] Skipped {skipped} duplicates already stored.")

            time.sleep(args.delay)

    print(f"\n[Done] Inserted {total_inserted} products. Skipped {total_skipped} duplicates.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
