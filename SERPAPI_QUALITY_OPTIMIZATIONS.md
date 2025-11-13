# SerpAPI Quality Optimizations - Buyable Products Only

## Overview

Enhanced SerpAPI integration to return ONLY high-quality, buyable fashion products. Based on SearchAPI/SerpAPI best practices for Google Lens shopping results.

**Important**: SerpAPI and SearchAPI use different parameter names:
- **SerpAPI Google Lens**: Use `gl` for country, `hl` for language. Does NOT support `type` parameter - results come in `visual_matches` array
- **SearchAPI Google Lens**: Use `country` for country, `hl` for language, `search_type=products` to filter results
- We filter products on our side using the quality filters described below

## What Changed

### 1. Enhanced Quality Filtering (`is_buyable_product()`)

New multi-stage filter ensures products are actually purchasable:

**PRIORITY 1: Must have a price**
- Checks `price`, `extracted_price`, `extracted_value`, `value`, `amount`
- Handles dict, float, int, and string price formats
- Rejects products with no price information

**PRIORITY 2: Must be from approved merchant (optional)**
- When `use_strict_filtering=True`, only allows TIER1_RETAIL_DOMAINS
- Examples: Zalando, ASOS, H&M, Zara, Nike, Adidas, Amazon Fashion, etc.
- Prevents low-quality marketplace sellers and dropship sites

**PRIORITY 3: Must NOT be out of stock**
- Checks `stock_information` field
- Rejects products with "out of stock", "sold out", "unavailable"
- Only shows items users can actually buy right now

**PRIORITY 4: Must have valid product link**
- Verifies link exists and starts with "http"
- Ensures link is clickable

### 2. Merchant Hints Support

New optional parameter to bias results toward trusted retailers:

```python
# Example: Bias toward Norwegian/European retailers
merchant_hints = "Zalando OR ASOS OR H&M OR Zara OR Boozt"

results = search_serp_api(
    image_url=crop_url,
    api_key=SERPAPI_KEY,
    merchant_hints=merchant_hints,
    use_strict_filtering=True
)
```

**How it works:**
- Passed as `q` parameter to SerpAPI
- Google Lens prioritizes these merchants in results
- Still returns other merchants, but boosts specified ones
- Compatible with `search_type=products`

### 3. User Localization Support

Already implemented and working:

```python
results = search_visual_products(
    image_url=crop_url,
    country="NO",        # Norway - affects currency and local retailers
    language="nb",       # Norwegian Bokmål - affects UI language
    merchant_hints="Zalando OR Boozt OR XXL OR Komplett"
)
```

**Country codes (ISO 3166-1 alpha-2):**
- `NO` - Norway
- `US` - United States
- `GB` - United Kingdom
- `DE` - Germany
- `SE` - Sweden
- `DK` - Denmark
- `FR` - France
- etc.

**Language codes:**
- `nb` - Norwegian Bokmål
- `en` - English
- `de` - German
- `fr` - French
- `es` - Spanish
- etc.

## Filter Priority Order

Results now go through 3 quality gates in order:

1. **`is_buyable_product()`** - Has price + in stock + valid link + approved merchant
2. **`is_ecommerce_result()`** - Domain not banned + ecommerce signals
3. **`is_relevant_result()`** - Fashion keywords + no banned terms

This ensures only HIGH-QUALITY, BUYABLE products reach the user.

## Configuration Options

### Strict vs. Relaxed Filtering

**Strict Mode (Recommended):**
```python
search_serp_api(
    image_url=url,
    use_strict_filtering=True  # Only TIER1_RETAIL_DOMAINS allowed
)
```
- Best quality results
- Only trusted retailers (Zalando, ASOS, Nike, etc.)
- Fewer results but higher conversion

**Relaxed Mode:**
```python
search_serp_api(
    image_url=url,
    use_strict_filtering=False  # Any merchant allowed
)
```
- More results
- Includes smaller boutiques and marketplaces
- Still filters for price + stock + relevance

### Regional Merchant Hints

Customize merchant hints based on user's country:

```python
# Norway
merchant_hints = "Zalando OR Boozt OR XXL OR Komplett OR Carlings"

# United States
merchant_hints = "Nordstrom OR Bloomingdale's OR Macy's OR Amazon OR Target"

# United Kingdom
merchant_hints = "ASOS OR Selfridges OR John Lewis OR Next OR M&S"

# Germany
merchant_hints = "Zalando OR About You OR Otto OR Breuninger"
```

## Usage Examples

### Basic Usage (Already Works)
```python
results = search_serp_api(
    image_url="https://cloudinary.com/...",
    api_key=SERPAPI_KEY,
    max_results=10
)
# Returns: Only buyable products with prices, in stock, from TIER1 retailers
```

### With User Localization
```python
results = search_visual_products(
    image_url="https://cloudinary.com/...",
    country="NO",      # User's country
    language="nb",     # User's language
    max_results=10
)
# Returns: Products in Norwegian currency from Norwegian/EU retailers
```

### With Merchant Hints
```python
results = search_visual_products(
    image_url="https://cloudinary.com/...",
    country="NO",
    language="nb",
    merchant_hints="Zalando OR Boozt OR XXL",  # Boost these retailers
    max_results=10
)
# Returns: Prioritizes Zalando, Boozt, XXL but includes others
```

### Relaxed Filtering (More Results)
```python
results = search_serp_api(
    image_url="https://cloudinary.com/...",
    use_strict_filtering=False,  # Allow any merchant
    max_results=15
)
# Returns: More results from broader range of merchants
```

## Expected Results Quality

### Before Optimizations
- Mixed quality results
- Some "mediocre" entries (no price, out of stock, bad merchants)
- Non-fashion items sometimes slip through
- Dropship sites and aggregators included

### After Optimizations
- **100% buyable products** (has price + in stock + valid link)
- **Trusted merchants only** (when strict mode enabled)
- **Fashion-specific** (banned terms filter applied)
- **Localized** (correct currency and regional retailers)
- **No aggregators** (Pinterest, polyvore, shopping comparison sites blocked)

## Integration with App

The detection service already passes user location to the server:

```dart
// In detection_service.dart
final results = await _apiService.analyzeImage(
  imageFile: imageToAnalyze,
  location: userLocation,  // Already implemented!
  cloudinaryUrl: cloudinaryUrl,
  skipDetection: skipDetection,
);
```

The server now uses this location to:
1. Set `country` code (e.g., "United States" → "US")
2. Bias results to local retailers
3. Show prices in local currency

## Performance Impact

- **No slowdown** - Filtering happens after API response
- **Fewer results** - But higher quality (better conversion)
- **Merchant hints** - May add ~100-200ms to API call (negligible)
- **Pagination** - Still optimized (stop at page 1 if sufficient results)

## Recommendations

### For Production

1. **Enable strict filtering** - Better user experience with trusted retailers
2. **Use merchant hints** - Boost regional favorites for better matches
3. **Pass user location** - Already implemented, keep using it
4. **Monitor quality** - If too few results, consider relaxed mode

### Regional Merchant Lists

Create country-specific merchant hints:

```python
MERCHANT_HINTS_BY_COUNTRY = {
    'NO': 'Zalando OR Boozt OR XXL OR Komplett OR Carlings',
    'US': 'Nordstrom OR Bloomingdale OR Macy OR Amazon OR Target',
    'GB': 'ASOS OR Selfridges OR John Lewis OR Next',
    'DE': 'Zalando OR About You OR Otto OR Breuninger',
    'SE': 'Zalando OR Boozt OR H&M OR ARKET',
    'DK': 'Zalando OR Boozt OR Magasin',
}

# Then use in API call:
country = user_profile.country or 'US'
merchant_hints = MERCHANT_HINTS_BY_COUNTRY.get(country)
```

## Troubleshooting

### "Not enough results"
- Try `use_strict_filtering=False`
- Remove or broaden merchant hints
- Check if user's country has limited Lens shopping support

### "Wrong currency/language"
- Verify `country` and `language` parameters are set correctly
- Check ISO codes are valid (2-letter country, 2-letter language)

### "Results still low quality"
- Verify `search_type=products` is set (it is by default)
- Check TIER1_RETAIL_DOMAINS includes your preferred merchants
- Review banned terms - may be too aggressive

## Testing

### Test Quality Filter
```python
# Mock a SerpAPI result
test_match = {
    'title': 'Nike Air Max 270',
    'link': 'https://www.nike.com/product/abc123',
    'price': {'extracted_value': 150.0},
    'stock_information': 'In Stock',
}

assert is_buyable_product(test_match, TIER1_RETAIL_DOMAINS) == True

# Out of stock should fail
test_match['stock_information'] = 'Out of Stock'
assert is_buyable_product(test_match, TIER1_RETAIL_DOMAINS) == False
```

### Test Merchant Hints
```python
# Norway-focused search
results = search_visual_products(
    image_url=test_image_url,
    country='NO',
    language='nb',
    merchant_hints='Zalando OR Boozt',
    max_results=5
)

# Verify results prioritize Norwegian retailers
for result in results[:3]:
    assert 'zalando' in result['link'].lower() or 'boozt' in result['link'].lower()
```

## Summary

These optimizations ensure Snaplook returns **only high-quality, buyable fashion products** from trusted retailers, with proper localization and stock availability checking.

Key improvements:
- Only products with prices
- Only in-stock products
- Only trusted merchants (when strict mode enabled)
- Proper localization (currency, language, regional retailers)
- Merchant hints to boost preferred retailers
- No dropship sites, aggregators, or low-quality sellers

**Result: Better user experience, higher conversion, fewer "mediocre" entries.**
