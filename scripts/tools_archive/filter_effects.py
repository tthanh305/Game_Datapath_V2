import urllib.request
import re

with open("scripts/fetch_effects.py") as f: pass

url = "https://particlefx.studio/effects"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=10) as resp:
    html = resp.read().decode("utf-8", errors="ignore")
    links = set(re.findall(r'/effects/[\w\-]+', html))

keywords = ["plasma", "detonation", "explosion", "nuclear", "shockwave", "afterburner", "thruster", "laser", "shield"]
matched = [l for l in links if any(k in l for k in keywords)]
print(f"Matched {len(matched)} relevant effects:")
for m in sorted(matched)[:40]:
    print("  ", m)

