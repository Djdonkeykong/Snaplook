import io
import sys
import os  # needed for environment variables
import json
import base64
import time
import torch
import requests
import re
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Set
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed  # parallel uploads

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

# === DOMAIN FILTERING (Ported from Flutter trusted_domains.dart) ===

# Tier-1 retailers / luxury stores to boost
TIER1_RETAIL_DOMAINS = {
    'nordstrom.com', 'selfridges.com', 'net-a-porter.com', 'mrporter.com',
    'theoutnet.com', 'harrods.com', 'harveynichols.com', 'brownsfashion.com',
    'bergdorfgoodman.com', 'saksfifthavenue.com', 'neimanmarcus.com',
    'bloomingdales.com', 'macys.com', 'matchesfashion.com', 'mytheresa.com',
    'shopbop.com', 'fwrd.com', 'endclothing.com', 'reformation.com',
    'ssense.com', 'farfetch.com', 'luisaviaroma.com', '24s.com',
}

# Marketplaces / peer-to-peer: penalize and cap at 1
MARKETPLACE_DOMAINS = {
    'amazon.com', 'amazon.co.uk', 'amazon.de', 'amazon.fr', 'amazon.it', 'amazon.es',
    'ebay.com', 'ebay.co.uk', 'etsy.com', 'aliexpress.com', 'alibaba.com',
    'dhgate.com', 'depop.com', 'poshmark.com', 'vestiairecollective.com',
    'therealreal.com', 'vinted.com', 'vinted.co.uk', 'stockx.com', 'goat.com',
    'zalando.com', 'zalando.de', 'zalando.no', 'zalando.co.uk',
    'shopee.com', 'lazada.com', 'rakuten.co.jp', 'walmart.com', 'target.com',
    'flipkart.com', 'noon.com', 'bol.com',
}

# Trusted mainstream fashion/apparel retail
TRUSTED_RETAIL_DOMAINS = {
    'asos.com', 'zara.com', 'hm.com', 'mango.com', 'uniqlo.com', 'cos.com',
    'weekday.com', 'monki.com', 'bershka.com', 'pullandbear.com',
    'stradivarius.com', 'massimodutti.com', 'primark.com', 'aritzia.com',
    'urbanoutfitters.com', 'anthropologie.com', 'freepeople.com', 'everlane.com',
    'madewell.com', 'revolve.com', 'boozt.com', 'only.com', 'jackjones.com',
    'na-kd.com', 'cottonon.com', 'showpo.com', 'beginningboutique.com',
    'tobi.com', 'windsorstore.com', 'garageclothing.com', 'lulus.com',
    'nike.com', 'adidas.com', 'puma.com', 'reebok.com', 'newbalance.com',
    'asics.com', 'vans.com', 'converse.com', 'underarmour.com', 'lululemon.com',
    'gymshark.com', 'fabletics.com', 'aloyoga.com', 'outdoorvoices.com',
    'patagonia.com', 'thenorthface.com', 'columbia.com', 'on-running.com',
    'salomon.com', 'merrell.com', 'teva.com', 'hoka.com', 'crocs.com',
    'birkenstock.com', 'drmartens.com', 'footlocker.com', 'finishline.com',
    'snipes.com', 'jdsports.com', 'jdsports.co.uk', 'champssports.com',
    'pandora.net', 'tiffany.com', 'cartier.com', 'rolex.com', 'tagheuer.com',
    'omegawatches.com', 'bulgari.com', 'breitling.com', 'longines.com',
    'fossil.com', 'danielwellington.com', 'mvmt.com', 'swarovski.com',
    'skagen.com', 'citizenwatch.com', 'seikowatches.com', 'cluse.com',
    'apm.mc', 'ray-ban.com', 'warbyparker.com', 'zennioptical.com',
    'eyebuydirect.com', 'oakley.com', 'persol.com', 'mauijim.com',
    'glassesusa.com', 'sunglasshut.com', 'smartbuyglasses.com',
    'samsonite.com', 'tumi.com', 'awaytravel.com', 'rimowa.com',
    'kipling.com', 'longchamp.com', 'coach.com', 'michaelkors.com',
    'katespade.com', 'guess.com', 'dooney.com', 'toryburch.com',
    'herschel.com', 'eastpak.com', 'jansport.com', 'pactwear.com',
    'tentree.com', 'girlfriend.com', 'organicbasics.com', 'kotn.com',
    'matethelabel.com', 'theslowlabel.com', 'cuyana.com', 'allbirds.com',
    'marksandspencer.com', 'houseoffraser.co.uk', 'johnlewis.com',
    'debenhams.com', 'myer.com.au', 'davidjones.com', 'century21stores.com',
    'lordandtaylor.com', 'boscovs.com', 'argos.co.uk', 'boots.com',
    'very.co.uk', 'next.co.uk', 'next.com', 'peek-cloppenburg.de',
    'galerieslafayette.com', 'otto.de', 'aboutyou.de', 'aboutyou.com',
    'bonprix.de',
}

# Aggregators / meta-shopping (penalize and cap at 1)
AGGREGATOR_DOMAINS = {
    'lyst.com', 'modesens.com', 'shopstyle.com', 'lyst.co.uk',
}

# Completely banned content/non-commerce domains
BANNED_DOMAINS = {
    # Social
    'facebook.com', 'instagram.com', 'twitter.com', 'x.com', 'pinterest.com',
    'tiktok.com', 'linkedin.com', 'reddit.com', 'youtube.com', 'snapchat.com',
    'threads.net', 'discord.com', 'wechat.com', 'weibo.com', 'line.me', 'vk.com',
    # Blogging
    'blogspot.com', 'wordpress.com', 'tumblr.com', 'medium.com', 'substack.com',
    'weebly.com', 'wixsite.com', 'squarespace.com', 'ghost.io', 'notion.site',
    'livejournal.com', 'typepad.com',
    # Reference
    'quora.com', 'fandom.com', 'wikipedia.org', 'wikihow.com', 'britannica.com',
    'stackexchange.com', 'stackoverflow.com', 'ask.com', 'answers.com',
    # News / Media
    'bbc.com', 'cnn.com', 'nytimes.com', 'washingtonpost.com', 'forbes.com',
    'bloomberg.com', 'reuters.com', 'huffpost.com', 'usatoday.com',
    'abcnews.go.com', 'cbsnews.com', 'npr.org', 'time.com', 'theguardian.com',
    'independent.co.uk', 'theatlantic.com', 'vox.com', 'buzzfeed.com',
    'vice.com', 'msn.com', 'dailymail.co.uk', 'mirror.co.uk', 'nbcnews.com',
    'latimes.com', 'insider.com',
    # Creative
    'soundcloud.com', 'deviantart.com', 'dribbble.com', 'artstation.com',
    'behance.net', 'vimeo.com', 'bandcamp.com', 'mixcloud.com', 'last.fm',
    'spotify.com', 'goodreads.com',
    # Editorial fashion (non-shoppable)
    'vogue.com', 'elle.com', 'harpersbazaar.com', 'cosmopolitan.com',
    'glamour.com', 'refinery29.com', 'whowhatwear.com', 'instyle.com',
    'graziamagazine.com', 'vanityfair.com', 'marieclaire.com', 'teenvogue.com',
    'stylecaster.com', 'popsugar.com', 'nylon.com', 'lifestyleasia.com',
    'thezoereport.com', 'allure.com', 'coveteur.com', 'thecut.com',
    'dazeddigital.com', 'highsnobiety.com', 'hypebeast.com', 'complex.com',
    'gq.com', 'esquire.com', 'menshealth.com', 'wmagazine.com', 'people.com',
    'today.com', 'observer.com', 'standard.co.uk', 'eveningstandard.co.uk',
    'nssmag.com', 'grazia.fr', 'grazia.it',
    # Tech
    'techcrunch.com', 'wired.com', 'theverge.com', 'engadget.com',
    'gsmarena.com', 'cnet.com', 'zdnet.com', 'mashable.com', 'makeuseof.com',
    'arstechnica.com', 'androidauthority.com', 'macrumors.com', '9to5mac.com',
    'digitaltrends.com', 'imore.com', 'tomsguide.com', 'pocket-lint.com',
    # Travel
    'tripadvisor.com', 'expedia.com', 'lonelyplanet.com', 'booking.com',
    'airbnb.com', 'travelandleisure.com', 'kayak.com', 'skyscanner.com',
    # Aggregators / spammy
    'dealmoon.com', 'pricegrabber.com', 'shopmania.com', 'trustpilot.com',
    'reviewcentre.com', 'mouthshut.com', 'sitejabber.com', 'lookbook.nu',
    'stylebistro.com', 'redbubble.com', 'society6.com', 'teepublic.com',
    'zazzle.com', 'spreadshirt.com', 'cafepress.com', 'archive.org',
    # Forums
    '4chan.org', '8kun.top', 'thefashionspot.com', 'styleforum.net',
    'superfuture.com',
    # Misc
    'patreon.com', 'onlyfans.com', 'ko-fi.com', 'buymeacoffee.com',
    'pixiv.net', 'tumgir.com',
}

# Combined trusted domains for general filtering
TRUSTED_DOMAINS = TIER1_RETAIL_DOMAINS | MARKETPLACE_DOMAINS | TRUSTED_RETAIL_DOMAINS | AGGREGATOR_DOMAINS

# === CATEGORY RULES (Ported from Flutter category_rules.dart) ===

CATEGORY_KEYWORDS_DETAILED = {
    'dresses': [
        'dress', 'gown', 'jumpsuit', 'romper', 'one-piece', 'one piece',
        'bodysuit', 'maxi dress', 'midi dress', 'mini dress', 'evening dress',
        'cocktail dress', 'slip dress',
    ],
    'tops': [
        'top', 'shirt', 't-shirt', 'tee', 'tank', 'blouse', 'polo', 'sweater',
        'hoodie', 'crewneck', 'jumper', 'camisole', 'cardigan', 'tunic',
        'long sleeve',
    ],
    'bottoms': [
        'jeans', 'pants', 'trouser', 'shorts', 'skirt', 'leggings', 'cargo',
        'chino', 'culotte', 'sweatpants', 'jogger', 'denim', 'slip skirt',
    ],
    'outerwear': [
        'coat', 'jacket', 'blazer', 'vest', 'trench', 'puffer', 'windbreaker',
        'parka', 'anorak', 'raincoat',
    ],
    'shoes': [
        'shoe', 'sneaker', 'boot', 'heel', 'loafer', 'flat', 'sandal',
        'slipper', 'moccasin', 'trainer', 'wedge', 'platform', 'flip-flop',
        'clog', 'oxford', 'derby', 'running shoe', 'tennis shoe', 'high top',
        'low top', 'slide',
    ],
    'bags': [
        'bag', 'handbag', 'tote', 'crossbody', 'backpack', 'satchel', 'clutch',
        'duffel', 'wallet', 'purse', 'briefcase',
    ],
    'headwear': [
        'hat', 'cap', 'beanie', 'beret', 'visor', 'bucket hat', 'headband',
    ],
    'accessories': [
        'scarf', 'belt', 'glasses', 'sunglasses', 'watch', 'earring',
        'necklace', 'bracelet', 'ring', 'tie', 'bowtie', 'pin', 'brooch',
        'glove', 'keychain', 'wallet',
    ],
}

BRAND_CATEGORY_HINTS = {
    # Footwear
    'nike': 'shoes', 'adidas': 'shoes', 'puma': 'shoes', 'vans': 'shoes',
    'converse': 'shoes', 'new balance': 'shoes', 'reebok': 'shoes',
    'asics': 'shoes', 'salomon': 'shoes', 'hoka': 'shoes', 'crocs': 'shoes',
    'dr martens': 'shoes', 'timberland': 'shoes',
    # Bags
    'coach': 'bags', 'michael kors': 'bags', 'kate spade': 'bags',
    'tory burch': 'bags', 'longchamp': 'bags', 'rimowa': 'bags',
    'samsonite': 'bags', 'away': 'bags', 'herschel': 'bags',
    # Apparel
    'zara': 'tops', 'h&m': 'tops', 'uniqlo': 'tops', 'asos': 'tops',
    'shein': 'tops', 'fashion nova': 'tops', 'boohoo': 'tops',
    'revolve': 'dresses', 'princess polly': 'dresses', 'lulus': 'dresses',
    'prettylittlething': 'dresses',
    # Outerwear
    'north face': 'outerwear', 'columbia': 'outerwear', 'patagonia': 'outerwear',
    'canada goose': 'outerwear', 'moncler': 'outerwear',
    # Eyewear & jewelry
    'ray-ban': 'accessories', 'oakley': 'accessories', 'warby parker': 'accessories',
    'pandora': 'accessories', 'tiffany': 'accessories', 'cartier': 'accessories',
    'swarovski': 'accessories',
}

STOP_WORDS = {
    'the', 'and', 'with', 'from', 'shop', 'buy', 'store', 'official',
    'for', 'by', 'men', 'women', 'kids', 'unisex', 'fashion', 'style',
    'clothing', 'apparel', 'brand', 'new', 'sale', 'discount', 'collection',
    'edition',
}

# Relevance filter - banned terms for non-fashion content
RELEVANCE_BANNED_TERMS = [
    'texture', 'pattern', 'drawing', 'illustration', 'clipart', 'mockup',
    'template', 'icon', 'logo', 'vector', 'stock photo', 'hanger', 'material',
    'silhouette', 'outline', 'preset', 'filter', 'lightroom', 'photoshop',
    'digital download', 'tutorial', 'guide', 'lesson', 'manual', 'holder',
    'stand', 'tripod', 'mount', 'case', 'charger', 'adapter', 'cable',
    'keyboard', 'mouse', 'phone', 'tablet', 'shoelace',
]

# Fashion keywords for relevance detection
GARMENT_KEYWORDS = [
    'dress', 'top', 'shirt', 't-shirt', 'pants', 'jeans', 'skirt', 'coat',
    'jacket', 'sweater', 'hoodie', 'bag', 'handbag', 'backpack', 'tote',
    'sandal', 'boot', 'shoe', 'sneaker', 'heel', 'glasses', 'sunglasses',
    'hat', 'cap', 'scarf', 'outfit', 'clothing', 'apparel', 'fashion',
]

# Style hint keywords for relevance boost
STYLE_HINT_KEYWORDS = ['silk', 'satin', 'lace', 'bias', 'midi', 'maxi', 'slip', 'trim']

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

class DetectAndSearchRequest(BaseModel):
    image_url: str
    serp_api_key: str
    threshold: Optional[float] = Field(default_factory=lambda: CONF_THRESHOLD)
    expand_ratio: Optional[float] = Field(default=EXPAND_RATIO)
    max_crops: Optional[int] = Field(default=MAX_GARMENTS)
    max_results_per_garment: Optional[int] = Field(default=10)

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

# === SOPHISTICATED FILTERING HELPERS (Ported from Flutter) ===

def extract_domain(url: str) -> str:
    """Extract root domain from URL (e.g., 'www.example.com' -> 'example.com')"""
    try:
        parsed = urlparse(url)
        host = parsed.netloc.replace('www.', '')
        parts = host.split('.')
        if len(parts) >= 2:
            return f"{parts[-2]}.{parts[-1]}"
        return host
    except:
        return ''

def domain_matches_any(domain: str, domain_set: Set[str]) -> bool:
    """Check if domain matches any domain in the set"""
    domain_lower = domain.lower()
    return any(domain_lower == root.lower() or domain_lower.endswith(f'.{root.lower()}')
               for root in domain_set)

def is_ecommerce_result(link: str, source: str, title: str, snippet: str = '') -> bool:
    """Filter to only ecommerce results using domain lists"""
    text = f"{link} {source} {title.lower()} {snippet.lower()}"
    domain = extract_domain(link).lower()

    # Fully banned content/non-commerce
    if domain_matches_any(domain, BANNED_DOMAINS):
        return False

    # If in trusted roots, allow early (strict mode)
    if domain_matches_any(domain, TRUSTED_DOMAINS):
        return True

    # Generic ecommerce hints
    has_price = bool(re.search(r'(\$|€|£|¥)\s?\d', text))
    has_cart = bool(re.search(r'(add[\s_-]?to[\s_-]?cart|buy\s?now|checkout|in\s?stock)', text, re.I))
    product_url = bool(re.search(r'/(product|shop|store|item|buy)[/\-_]', link, re.I))

    return has_price or has_cart or product_url

def is_relevant_result(title: str) -> bool:
    """Semantic relevance filter - blocks textures, patterns, tutorials, etc."""
    lower = title.lower()

    # Banned terms
    if any(term in lower for term in RELEVANCE_BANNED_TERMS):
        return False

    # Expected garment keywords
    if any(keyword in lower for keyword in GARMENT_KEYWORDS):
        return True

    # Style hints
    if any(hint in lower for hint in STYLE_HINT_KEYWORDS):
        return True

    return False

def format_title(title: str) -> str:
    """Format title by removing marketing fluff and cleaning up"""
    if not title:
        return 'Unknown item'

    clean = title

    # Remove marketing / store fluff
    clean = re.sub(
        r'(buy\s+now|official\s+store|free\s+shipping|online\s+shop|sale|discount|deal|brand\s+new|shop\s+now)',
        '',
        clean,
        flags=re.I
    )

    # Split on common separators and keep the most informative part
    parts = re.split(r'[\|\-:–—]+', clean)
    if parts:
        good_parts = [p.strip() for p in parts if re.search(r'[a-zA-Z]', p.strip())]
        if good_parts:
            clean = good_parts[0]

    # Normalize whitespace
    clean = re.sub(r'\s+', ' ', clean).strip()

    # Capitalize first letter
    if clean:
        clean = clean[0].upper() + clean[1:]

    # Limit length
    if len(clean) > 60:
        clean = clean[:57] + '...'

    return clean if clean else 'Unknown item'

def extract_brand(title: str, source: str) -> str:
    """Extract brand from source or title"""
    if source:
        return title_case(source)

    # Try to extract first few words from title
    match = re.match(r"^[A-Za-z0-9'& ]{2,20}", title)
    if match:
        candidate = match.group(0).strip()
        if candidate and candidate.lower() not in STOP_WORDS:
            return title_case(candidate)

    return 'Unknown'

def title_case(value: str) -> str:
    """Convert string to title case"""
    return ' '.join(word[0].upper() + word[1:].lower()
                   for word in value.split() if word)

def categorize_garment(title: str, brand: str = '') -> str:
    """
    Sophisticated categorization using keyword matching and brand hints.
    Ported from Flutter detection_service.dart
    """
    lower = title.lower()
    brand_lower = brand.lower() if brand else ''

    # Token-vote scoring across all categories
    def score_token(token: str) -> int:
        pattern = r'\b' + re.escape(token) + r'\b'
        if re.search(pattern, lower):
            return 2
        return 1 if token in lower else 0

    votes = {}
    for category, keywords in CATEGORY_KEYWORDS_DETAILED.items():
        votes[category] = sum(score_token(kw) for kw in keywords)

    # Priority order for tie-breaking
    priority = ['bottoms', 'dresses', 'tops', 'outerwear', 'shoes', 'bags', 'accessories', 'headwear']

    # Find best category by vote
    best_category = 'accessories'
    best_score = -1
    for cat in priority:
        if votes.get(cat, 0) > best_score:
            best_score = votes.get(cat, 0)
            best_category = cat

    # Check brand hints
    for brand_key, hint_category in BRAND_CATEGORY_HINTS.items():
        if brand_key in brand_lower or brand_key in lower:
            # If brand hint has equal or better vote, use it
            if votes.get(hint_category, 0) >= best_score * 0.8:
                return hint_category

    return best_category

def looks_like_pdp(url: str, title: str) -> bool:
    """Check if URL/title looks like a Product Detail Page"""
    url_lower = url.lower()
    title_lower = title.lower()

    pdp_url_pattern = r'/product/|/products?/|/p/|/pd/|/sku/|/item/|/buy/|/dp/|/gp/product/|/shop/[^/]*\d'
    pdp_title_pattern = r'\b(sku|style|model|size|midi|maxi|silk|satin|lace)\b'

    return bool(re.search(pdp_url_pattern, url_lower)) or bool(re.search(pdp_title_pattern, title_lower))

def looks_like_collection(url: str, title: str) -> bool:
    """Check if URL/title looks like a generic collection/landing page"""
    url_lower = url.lower()
    title_lower = title.lower()

    # Title pattern: "Category | Store"
    if re.search(r'\b(women|men|kids|midi|maxi|skirts?|dresses|clothing)\b', title_lower) and ' | ' in title_lower:
        return True

    # Collection/category URLs
    collection_pattern = r'/c/|/category/|/collections?/|/shop/[^/]+/?$|/women/[^/]+/?$|/women/?$|/new-arrivals/?$|/sale/?$'
    if re.search(collection_pattern, url_lower):
        return True

    # Index pages
    if url_lower.endswith('/index.html') or url_lower.endswith('/index'):
        return True

    return False

def fashion_score(result: dict, price: float) -> float:
    """
    Fashion-aware scoring with tier-1 boost, marketplace penalty, style keywords.
    Ported from Flutter detection_service.dart
    """
    purchase_url = result.get('purchase_url', '')
    product_name = result.get('product_name', '')
    domain = extract_domain(purchase_url)

    mult = 1.0

    # Trust & prestige
    if domain_matches_any(domain, TIER1_RETAIL_DOMAINS):
        mult *= 1.15
    if domain_matches_any(domain, MARKETPLACE_DOMAINS):
        mult *= 0.88
    if domain_matches_any(domain, AGGREGATOR_DOMAINS):
        mult *= 0.90

    # Style keywords
    title_lower = product_name.lower()
    if 'silk' in title_lower:
        mult *= 1.06
    if 'satin' in title_lower:
        mult *= 1.06
    if 'lace' in title_lower:
        mult *= 1.08
    if 'midi' in title_lower:
        mult *= 1.03
    if 'slip' in title_lower:
        mult *= 1.04

    if price > 0:
        mult *= 1.02

    base = 0.75  # Base confidence for serp results
    return base * mult

def deduplicate_and_limit_by_domain(results: List[dict]) -> List[dict]:
    """
    Deduplicate results by domain with caps:
    - Marketplaces/aggregators: max 1
    - Tier-1: max 7
    - Trusted retail: max 5
    - Others: max 3

    Prefer PDPs over collection pages within each domain.
    Ported from Flutter detection_service.dart
    """
    # Sort by fashion score
    results.sort(key=lambda r: fashion_score(r, r.get('price', 0.0)), reverse=True)

    by_domain = {}
    domain_count = {}
    seen_urls = set()

    for result in results:
        url = result.get('purchase_url', '').strip()
        if not url or url in seen_urls:
            continue

        seen_urls.add(url)
        domain = extract_domain(url)
        if not domain:
            continue

        is_tier1 = domain_matches_any(domain, TIER1_RETAIL_DOMAINS)
        is_marketplace = domain_matches_any(domain, MARKETPLACE_DOMAINS)
        is_aggregator = domain_matches_any(domain, AGGREGATOR_DOMAINS)
        is_trusted_retail = domain_matches_any(domain, TRUSTED_RETAIL_DOMAINS)

        # Determine cap
        if is_marketplace or is_aggregator:
            cap = 1
        elif is_tier1:
            cap = 7
        elif is_trusted_retail:
            cap = 5
        else:
            cap = 3

        if domain not in by_domain:
            by_domain[domain] = []
            domain_count[domain] = 0

        domain_list = by_domain[domain]

        if domain_count[domain] < cap:
            # Room available
            domain_list.append(result)
            domain_count[domain] += 1
        else:
            # At cap: if current is PDP and any existing is not PDP, replace lowest-score non-PDP
            curr_is_pdp = looks_like_pdp(url, result.get('product_name', ''))
            if not curr_is_pdp:
                continue

            # Find lowest-score non-PDP in this domain
            replace_idx = -1
            worst_score = float('inf')
            for i, existing in enumerate(domain_list):
                existing_is_pdp = looks_like_pdp(
                    existing.get('purchase_url', ''),
                    existing.get('product_name', '')
                )
                if not existing_is_pdp:
                    score = fashion_score(existing, existing.get('price', 0.0))
                    if score < worst_score:
                        worst_score = score
                        replace_idx = i

            if replace_idx >= 0:
                domain_list[replace_idx] = result

    # Flatten results
    flattened = []
    for domain_list in by_domain.values():
        flattened.extend(domain_list)

    print(f"Deduped {len(flattened)} results across {len(by_domain)} domains")
    return flattened

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

# === SERP API SEARCH HELPERS ===
def download_image_from_url(image_url: str) -> Image.Image:
    """Download image from URL and return PIL Image."""
    print(f"📥 Downloading image from: {image_url}")
    response = requests.get(image_url, timeout=15)
    if response.status_code != 200:
        raise Exception(f"Failed to download image: {response.status_code}")
    return Image.open(io.BytesIO(response.content)).convert("RGB")

def search_serp_api(image_url: str, api_key: str, max_results: int = 10) -> List[dict]:
    """
    Search Google Lens via SerpAPI and return top filtered results.
    Now applies sophisticated ecommerce and relevance filtering.
    """
    print(f"🔍 Searching SerpAPI for image: {image_url[:80]}...")

    results = []
    for rail in ['products', 'visual_matches']:
        params = {
            'engine': 'google_lens',
            'api_key': api_key,
            'url': image_url,
            'type': rail,
        }

        try:
            response = requests.get('https://serpapi.com/search', params=params, timeout=15)
            if response.status_code != 200:
                print(f"⚠️ SerpAPI {rail} failed: {response.status_code}")
                continue

            data = response.json()
            if 'error' in data:
                print(f"⚠️ SerpAPI {rail} error: {data['error']}")
                continue

            matches = data.get('visual_matches', [])
            for match in matches:
                link = match.get('link', '')
                title = match.get('title', '')
                source = match.get('source', '')
                thumbnail = match.get('thumbnail', '')
                snippet = match.get('snippet', '')

                # Basic validation
                if not link or not title:
                    continue

                # Apply sophisticated filtering (ported from Flutter)
                if not is_ecommerce_result(link, source, title, snippet):
                    continue

                if not is_relevant_result(title):
                    continue

                # Extract price if available
                price = 0.0
                price_obj = match.get('price', {})
                if isinstance(price_obj, dict):
                    price = price_obj.get('extracted_value', 0.0)

                results.append({
                    'title': title,
                    'link': link,
                    'source': source,
                    'thumbnail': thumbnail,
                    'snippet': snippet,
                    'price': price,
                })

                if len(results) >= max_results * 2:  # Fetch extra before dedup
                    break

            if len(results) >= max_results * 2:
                break

        except Exception as e:
            print(f"❌ SerpAPI {rail} error: {e}")
            continue

    print(f"✅ Found {len(results)} filtered results from SerpAPI")
    return results

def format_detection_result(serp_result: dict, garment_label: str, index: int) -> dict:
    """
    Format a SerpAPI result into DetectionResult-like structure.
    Now uses sophisticated title formatting, brand extraction, and categorization.
    """
    raw_title = serp_result['title']
    raw_source = serp_result.get('source', '')
    purchase_url = serp_result['link']
    price = serp_result.get('price', 0.0)

    # Apply sophisticated helpers
    formatted_title = format_title(raw_title)
    brand = extract_brand(raw_title, raw_source)
    category = categorize_garment(formatted_title, brand)

    return {
        'id': f'serp_{int(time.time() * 1000)}_{index}',
        'product_name': formatted_title,
        'brand': brand,
        'price': price,
        'image_url': serp_result.get('thumbnail', ''),
        'category': category,
        'confidence': 0.75,
        'description': serp_result.get('snippet', '')[:200] if serp_result.get('snippet') else None,
        'purchase_url': purchase_url,
    }

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

# === DETECT AND SEARCH ENDPOINT (For Share Extension) ===
@app.post("/detect-and-search")
def detect_and_search(req: DetectAndSearchRequest):
    """
    Full pipeline: Download image -> Detect garments -> Search SerpAPI -> Return results.
    Designed for iOS share extension to show results in modal.
    """
    try:
        print(f"🚀 Starting detect-and-search pipeline for: {req.image_url[:80]}...")

        # Step 1: Download image from URL
        image = download_image_from_url(req.image_url)
        print(f"✅ Image downloaded: {image.width}x{image.height}")

        # Step 2: Run YOLOS detection
        filtered = run_detection(image, req.threshold, req.expand_ratio, req.max_crops)

        if not filtered:
            return {
                'success': False,
                'message': 'No garments detected in image',
                'results': []
            }

        # Step 3: Crop all garments and upload to ImgBB
        imgbb_api_key = "d7e1d857e4498c2e28acaa8d943ccea8"
        crops_with_urls = []

        print(f"🔍 Processing {len(filtered)} detected garments...")
        for det in filtered:
            x1, y1, x2, y2 = expand_bbox(det["bbox"], image.width, image.height, req.expand_ratio)
            crop = image.crop((x1, y1, x2, y2))

            # Upload crop to ImgBB
            crop_url = upload_to_imgbb(crop, imgbb_api_key)
            if crop_url:
                crops_with_urls.append({
                    'garment': det,
                    'crop_url': crop_url
                })
                print(f"✅ Uploaded {det['label']} crop: {crop_url}")

        if not crops_with_urls:
            return {
                'success': False,
                'message': 'Failed to upload garment crops',
                'results': []
            }

        # Step 4: Search SerpAPI for each garment crop
        all_results = []
        for item in crops_with_urls:
            garment = item['garment']
            crop_url = item['crop_url']

            print(f"🔍 Searching SerpAPI for {garment['label']} (score: {garment['score']:.3f})...")

            serp_results = search_serp_api(
                crop_url,
                req.serp_api_key,
                max_results=req.max_results_per_garment
            )

            # Format and add to results
            for i, serp_result in enumerate(serp_results):
                formatted = format_detection_result(serp_result, garment['label'], len(all_results) + i)
                all_results.append(formatted)

        print(f"📊 Total raw results before filtering: {len(all_results)}")

        # Step 5: Apply sophisticated filtering
        # Remove collection pages if we have enough PDPs
        pdp_count = sum(1 for r in all_results if not looks_like_collection(
            r.get('purchase_url', ''), r.get('product_name', '')
        ))

        if pdp_count >= 10:
            before = len(all_results)
            all_results = [r for r in all_results if not looks_like_collection(
                r.get('purchase_url', ''), r.get('product_name', '')
            )]
            print(f"🧹 Removed {before - len(all_results)} collection pages (kept PDPs)")

        # Step 6: Deduplicate and limit by domain with fashion scoring
        deduped_results = deduplicate_and_limit_by_domain(all_results)

        print(f"✅ Pipeline complete. Returning {len(deduped_results)} high-quality results from {len(crops_with_urls)} garments")

        return {
            'success': True,
            'detected_garment': {
                'label': filtered[0]['label'],
                'score': round(filtered[0]['score'], 3),
                'bbox': filtered[0]['bbox']
            },
            'total_results': len(deduped_results),
            'results': deduped_results
        }

    except Exception as e:
        print(f"❌ detect-and-search failed: {e}")
        import traceback
        traceback.print_exc()
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
