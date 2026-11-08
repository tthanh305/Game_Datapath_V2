import urllib.request
import re

effect_urls = [
    "https://particlefx.studio/effects/pixel-art-boss-explosion",
    "https://particlefx.studio/effects/pixel-art-plasma-orb",
    "https://particlefx.studio/effects/pixel-art-explosion",
    "https://particlefx.studio/effects/jet-thruster-flame",
]

for url in effect_urls:
    print("Checking:", url)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            page = resp.read().decode("utf-8", errors="ignore")
            # Tìm ảnh gif, png, webp, spritesheet
            imgs = re.findall(r'https?://[^\s\"\']+\.(?:png|gif|webp)', page)
            print("  Found images:", len(imgs))
            for img in set(imgs):
                if any(x in img.lower() for x in ["preview", "sprite", "sheet", "render", "effect", "cdn", "assets"]):
                    print("   ->", img)
    except Exception as e:
        print("  Error:", e)

