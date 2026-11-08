import urllib.request
from pathlib import Path
from PIL import Image

out_dir = Path("assets/downloaded_fx")
out_dir.mkdir(parents=True, exist_ok=True)

# Các poster và strip chính thức từ ParticleFX Studio
fx_targets = {
    # 1. Pixel Art Boss Explosion (Chuỗi nổ trùm hoành tráng: vệt sáng, cầu lửa, sóng kích, bay đá)
    "boss_strip.webp": "https://particlefx.studio/strips/pixel-art-combat/pixelArtBossExplosion.webp",
    "boss_poster.webp": "https://particlefx.studio/posters/pixel-art-combat/pixelArtBossExplosion.webp",
    # 2. Digital Explosion Pixel Art (Vụ nổ kỹ thuật số Cyberpunk glitch)
    "digital_exp.webp": "https://particlefx.studio/posters/cyberpunk-glitch/digitalExplosionPixel.webp",
    # 3. Pixel Art Small Explosion (Nổ quái nhanh gọn sắc nét)
    "small_exp.webp": "https://particlefx.studio/posters/pixel-art-combat/pixelArtSmallExplosion.webp",
    # 4. Boss Defeat (Hiệu ứng hạ gục Boss retro)
    "boss_defeat.webp": "https://particlefx.studio/posters/retro-pixel/bossDefeat.webp"
}

headers = {"User-Agent": "Mozilla/5.0"}
for fname, url in fx_targets.items():
    print(f"Downloading {fname} from {url}...")
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = resp.read()
            dest = out_dir / fname
            with open(dest, "wb") as f:
                f.write(data)
            print(f"  -> Saved {dest.name} ({len(data)} bytes)")
    except Exception as e:
        print(f"  -> Failed: {e}")

print("\nDone downloading from ParticleFX Studio!")

