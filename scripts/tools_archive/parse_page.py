import urllib.request
import re

url = "https://particlefx.studio/effects/pixel-art-boss-explosion"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req) as resp:
    page = resp.read().decode("utf-8")
    for line in page.splitlines():
        if any(ext in line for ext in [".png", ".gif", ".webp", "spritesheet"]):
            print(line.strip())

