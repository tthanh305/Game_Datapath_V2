import urllib.request
import re

url = "https://particlefx.studio/effects"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        html = resp.read().decode("utf-8", errors="ignore")
        print(f"Page length: {len(html)}")
        links = set(re.findall(r'/effects/[\w\-]+', html))
        print(f"Found {len(links)} effect links:")
        for l in sorted(links)[:25]:
            print("  ", l)
except Exception as e:
    print("Error:", e)

