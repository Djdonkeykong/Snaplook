import os
import argparse
import math
import re
from urllib.parse import urlparse

import requests
from dotenv import load_dotenv
from serpapi import GoogleSearch  # type: ignore
from supabase import create_client, Client

# Minimum pixel area filter (width * height); default ~2MP
MIN_PIXELS = 2_000_000


def is_allowed(url: str, allowed_domains, path_prefixes: list[str] | None) -> bool:
    if not url:
        return False
    try:
        parsed = urlparse(url)
        host = parsed.hostname or ""
        path = parsed.path or ""
    except Exception:
        return False
    host = host.lower()
    domain_ok = allowed_domains == ["*"] or any(host == d or host.endswith("." + d) for d in allowed_domains)
    if not domain_ok:
        return False
    if path_prefixes:
        return any(path.startswith(prefix) for prefix in path_prefixes)
    return True


def meets_quality(img: dict) -> bool:
    h = img.get("original_height")
    w = img.get("original_width")
    try:
        h_val = int(h)
        w_val = int(w)
    except (TypeError, ValueError):
        return False
    if h_val > 0 and w_val > 0:
        return h_val * w_val >= MIN_PIXELS
    return False


def fetch_price(url: str, timeout: float = 5.0) -> str | None:
    """Best-effort price extractor from product pages; returns string or None."""
    if not url:
        return None
    try:
        resp = requests.get(
            url,
            timeout=timeout,
            headers={"User-Agent": "Mozilla/5.0 (compatible; SnaplookBot/1.0)"},
        )
    except Exception:
        return None
    if resp.status_code >= 400 or not resp.text:
        return None
    html = resp.text

    # 1) OpenGraph product price
    m = re.search(r'property=["\']product:price:amount["\'][^>]+content=["\']([^"\']+)["\']', html, re.IGNORECASE)
    if m:
        return m.group(1).replace(",", "").strip()

    # 2) JSON-LD "price"
    m = re.search(r'"price"\s*:\s*"?(\\d+[\\.,]?\\d*)"?', html)
    if m:
        return m.group(1).replace(",", "").strip()

    # 3) Currency symbol + amount
    m = re.search(r'(?:£|\$|€)\s?(\\d+[\\.,]?\\d*)', html)
    if m:
        return m.group(1).replace(",", "").strip()

    return None


def run_search(query: str, api_key: str, num: int):
    """Fetch up to `num` images with pagination (SerpApi returns ~100 per page)."""
    per_page = 100
    pages = math.ceil(num / per_page)
    all_images = []
    for page in range(pages):
        params = {
            "engine": "google_images",
            "q": query,
            "num": per_page,
            "ijn": page,  # pagination index
            "imgsz": "2mp",  # ask Google for >= 2 MP
            "api_key": api_key,
        }
        results = GoogleSearch(params).get_dict()
        if "error" in results:
            print(f"SerpApi error: {results['error']}")
            break
        images = results.get("images_results", [])
        all_images.extend(images)
        if not images or len(images) < per_page:
            meta = results.get("search_metadata", {}) or {}
            print(f"No more results after page {page}. SerpApi status: {meta.get('status')} url: {meta.get('google_images_url')}")
            break
    return all_images[:num]


def build_rows(
    images,
    allowed_domains,
    path_prefixes: list[str] | None,
    category: str,
    price_override,
    skip_price_fetch: bool,
    price_timeout: float,
    target_gender: str | None,
    brand: str | None,
):
    """Build rows matching public.products schema: id, title, price (text), image_url, url, category, source (+optional target_gender, brand)."""
    rows = []
    stats = {"total": 0, "domain_fail": 0, "quality_fail": 0, "kept": 0}
    for img in images:
        stats["total"] += 1
        link = img.get("link")
        original = img.get("original")
        domain_ok = allowed_domains == ["*"] or (
            is_allowed(link, allowed_domains, path_prefixes) or is_allowed(original, allowed_domains, path_prefixes)
        )
        if not domain_ok:
            stats["domain_fail"] += 1
            continue
        if not meets_quality(img):
            stats["quality_fail"] += 1
            continue
        price_val = price_override if price_override is not None else (None if skip_price_fetch else fetch_price(link, timeout=price_timeout))
        if price_val is not None:
            price_val = str(price_val)
        source_host = None
        try:
            source_host = urlparse(link or "").hostname
        except Exception:
            source_host = None
        # products.id is bigint; derive a positive int from uuid4
        raw_id = __import__("uuid").uuid4().int & ((1 << 63) - 1)
        row = {
            "id": raw_id,
            "title": img.get("title") or "Untitled",
            "price": price_val,
            "image_url": original or link,
            "url": link,
            "category": category,
            "source": source_host,
        }
        if target_gender is not None:
            row["target_gender"] = target_gender
        if brand is not None:
            row["brand"] = brand
        rows.append(row)
        stats["kept"] += 1
    return rows, stats


def insert_rows(supabase: Client, table: str, rows):
    if not rows:
        print("No rows to insert (no matches).")
        return
    resp = supabase.table(table).insert(rows).execute()
    if getattr(resp, "error", None):
        raise RuntimeError(resp.error)
    print(f"Inserted {len(rows)} rows.")


def dedupe_by_url(supabase: Client, table: str, rows):
    """Remove rows whose url already exists in the table."""
    urls = [r["url"] for r in rows if r.get("url")]
    if not urls:
        return rows, 0
    try:
        resp = supabase.table(table).select("url").in_("url", urls).execute()
    except Exception as exc:
        print(f"Warning: dedupe check failed, proceeding without dedupe: {exc}")
        return rows, 0
    existing = set()
    data = getattr(resp, "data", None)
    if isinstance(data, list):
        for item in data:
            u = item.get("url")
            if u:
                existing.add(u)
    filtered = [r for r in rows if r.get("url") not in existing]
    skipped = len(rows) - len(filtered)
    return filtered, skipped


def main():
    global MIN_PIXELS
    load_dotenv()  # pull keys from .env if present

    parser = argparse.ArgumentParser(description="SerpApi to Supabase product ingester")
    parser.add_argument("--query", required=True)
    parser.add_argument("--category", default="inspiration")
    parser.add_argument("--price", type=str, default=None, help="Optional manual price override (stored as text)")
    parser.add_argument("--target-gender", type=str, default=None, help="Optional target gender to store if the column exists")
    parser.add_argument("--table", default="products", help="Supabase table name")
    parser.add_argument("--brand", type=str, default=None, help="Optional brand to store if the column exists")
    parser.add_argument("--domains", default="www.weekday.com", help="Comma-separated allowed domains; use * to allow any")
    parser.add_argument(
        "--path-prefix",
        default="/en-ww/p",
        help="Optional required URL path prefix(es), comma-separated (e.g., /en-ww/p). Leave empty to disable path filtering.",
    )
    parser.add_argument(
        "--auto-site-query",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="If enabled and a single allowed domain is set, prefix the query with site:<domain> to focus results.",
    )
    parser.add_argument("--num", type=int, default=1000, help="Number of image results to fetch (default 1000)")
    parser.add_argument("--min-pixels", type=int, default=MIN_PIXELS, help="Minimum pixels (width*height) required")
    parser.add_argument("--skip-price-fetch", action="store_true", help="Skip fetching price from product pages")
    parser.add_argument("--price-timeout", type=float, default=5.0, help="Timeout (seconds) for price fetch HTTP requests")
    args = parser.parse_args()

    # Prefer the special key if present, otherwise fall back to existing keys
    serpapi_key = os.environ.get("SERPAPI_SPECIAL_API_KEY") or os.environ.get("SERPAPI_KEY") or os.environ.get("SERPAPI_API_KEY")
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_SERVICE_KEY")

    if not serpapi_key or not supabase_url or not supabase_key:
        missing = [name for name, val in {
            "SERPAPI_SPECIAL_API_KEY/SERPAPI_KEY/SERPAPI_API_KEY": serpapi_key,
            "SUPABASE_URL": supabase_url,
            "SUPABASE_SERVICE_ROLE_KEY/SUPABASE_SERVICE_KEY": supabase_key,
        }.items() if not val]
        raise SystemExit(f"Missing required environment vars: {', '.join(missing)}")

    allowed_domains = [d.strip().lower() for d in args.domains.split(",") if d.strip()]
    path_prefixes = [p.strip() if p.strip().startswith("/") else "/" + p.strip() for p in args.path_prefix.split(",") if p.strip()] or None

    MIN_PIXELS = args.min_pixels

    if args.auto_site_query and allowed_domains != ["*"] and len(allowed_domains) == 1 and "site:" not in args.query:
        args.query = f"site:{allowed_domains[0]} {args.query}"

    images = run_search(args.query, serpapi_key, args.num)
    rows, stats = build_rows(
        images,
        allowed_domains,
        path_prefixes,
        args.category,
        args.price,
        args.skip_price_fetch,
        args.price_timeout,
        args.target_gender,
        args.brand,
    )
    print(f"Fetched {stats['total']} images; kept {stats['kept']}; domain_fail {stats['domain_fail']}; quality_fail {stats['quality_fail']}.")

    supabase = create_client(supabase_url, supabase_key)
    rows, skipped_dupes = dedupe_by_url(supabase, args.table, rows)
    if skipped_dupes:
        print(f"Skipped {skipped_dupes} duplicates based on url.")
    insert_rows(supabase, args.table, rows)


if __name__ == "__main__":
    main()
