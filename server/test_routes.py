import sys
import os

# Set console encoding to UTF-8 to avoid Unicode errors
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

from fashion_detector_server import app

print("\nRegistered API Routes:")
print("=" * 60)
for route in app.routes:
    if hasattr(route, 'methods') and hasattr(route, 'path'):
        methods = ', '.join(route.methods)
        print(f"{methods:20} {route.path}")

print("\nLooking for caching routes...")
caching_routes = [r for r in app.routes if hasattr(r, 'path') and '/api/v1/' in r.path]
if caching_routes:
    print(f"\nFound {len(caching_routes)} caching routes:")
    for route in caching_routes:
        if hasattr(route, 'methods'):
            methods = ', '.join(route.methods)
            print(f"  {methods:20} {route.path}")
else:
    print("\nNo caching routes found")
