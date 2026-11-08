"""
=============================================================================
CONVERT STEREDENN ASSETS TO COMBINED HEX & COE BANKS
=============================================================================
Tạo 3 bank chính:
1. steredenn_ship_bank.hex:
   - 5 frames Ship Banking (5 x 1024 = 5120 words)
   - 4 frames Thruster (4 x 256 = 1024 words)
   - 3 frames Hit Sparks (3 x 256 = 768 words)
2. steredenn_enemy_bank.hex:
   - Boss f0..f1 (2048 words), Escort f0..f1 (2048 words), Drone f0..f1 (2048 words) = 6144 words
3. steredenn_exp_bank.hex:
   - 16 frames Massive Explosion 64x64 (16 x 4096 = 65536 words)
=============================================================================
"""

from pathlib import Path
from PIL import Image

ST_DIR = Path("assets/sprites/steredenn")
SP_DIR = Path("assets/sprites")
GEN_DIR = Path("assets/sprites/generated")
GEN_DIR.mkdir(parents=True, exist_ok=True)

def img_to_hex_words(img):
    img = img.convert("RGBA")
    w, h = img.size
    words = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                words.append("000000")
            else:
                val = (r << 16) | (g << 8) | b
                words.append(f"{val:06X}")
    return words

# 1. SHIP BANK (5 Ship Banks + 4 Thrusters + 3 Hit Sparks)
ship_words = []
for i in range(5):
    img = Image.open(ST_DIR / f"ship_bank_f{i}.png")
    ship_words.extend(img_to_hex_words(img))
for i in range(4):
    img = Image.open(ST_DIR / f"thruster_f{i}.png")
    ship_words.extend(img_to_hex_words(img))
for i in range(3):
    img = Image.open(ST_DIR / f"hit_spark_f{i}.png")
    ship_words.extend(img_to_hex_words(img))

with open(GEN_DIR / "steredenn_ship_bank.hex", "w") as fp:
    for w in ship_words: fp.write(w + "\n")
print(f"Generated steredenn_ship_bank.hex: {len(ship_words)} words")

# 2. ENEMY BANK (Boss, Escort, Drone)
enemy_words = []
for name in ["boss_f0.png", "boss_f1.png", "escort_f0.png", "escort_f1.png", "drone_f0.png", "drone_f1.png"]:
    img = Image.open(SP_DIR / name)
    enemy_words.extend(img_to_hex_words(img))

with open(GEN_DIR / "steredenn_enemy_bank.hex", "w") as fp:
    for w in enemy_words: fp.write(w + "\n")
print(f"Generated steredenn_enemy_bank.hex: {len(enemy_words)} words")

# 3. EXP BANK (16 Frames 64x64)
exp_words = []
for i in range(16):
    img = Image.open(ST_DIR / f"steredenn_exp_f{i}.png")
    exp_words.extend(img_to_hex_words(img))

with open(GEN_DIR / "steredenn_exp_bank.hex", "w") as fp:
    for w in exp_words: fp.write(w + "\n")
print(f"Generated steredenn_exp_bank.hex: {len(exp_words)} words (16 frames x 4096 words)")

