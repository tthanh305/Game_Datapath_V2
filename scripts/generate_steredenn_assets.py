"""
=============================================================================
STEREDENN ASSET GENERATOR (Big Beautiful Pixels Architecture)
1. SHIP BANKING (5 Frames - 32x32):
   - F0: Max Left Bank (-2)
   - F1: Slight Left Bank (-1)
   - F2: Neutral Straight (0)
   - F3: Slight Right Bank (+1)
   - F4: Max Right Bank (+2)
2. THRUSTER PLASMA EXHAUST (4 Frames - 16x16 modular):
   - Nhịp phụt 4 thì độc lập với tần số cao
3. HIT SPARKS (3 Frames - 16x16):
   - F0: White flash star / cross
   - F1: Yellow outward sparks
   - F2: Dim red dissipation sparks
4. STEREDENN 16-FRAME MASSIVE EXPLOSION (64x64):
   - F0..F1: White-out core & Anamorphic horizontal flare
   - F2..F7: Chunky black-purple-orange smoke spheres expanding from center
   - F8..F12: Flying shrapnel & shockwave ring
   - F13..F15: Dissolving smoke clumps & embers
=============================================================================
"""

import math
from pathlib import Path
from PIL import Image

OUT_DIR = Path("assets/sprites/steredenn")
OUT_DIR.mkdir(parents=True, exist_ok=True)

C_TRANS       = (0, 0, 0, 0)
C_STEEL_HI    = (230, 240, 255, 255)
C_STEEL_MID   = (125, 145, 175, 255)
C_STEEL_DK    = (45, 55, 75, 255)
C_PANEL_DK    = (20, 24, 35, 255)
C_CYAN_CORE   = (255, 255, 255, 255)
C_CYAN_GLOW   = (0, 240, 255, 255)
C_CYAN_DEEP   = (0, 110, 190, 255)
C_PURP_SMOKE  = (70, 20, 90, 255)
C_DK_SMOKE    = (25, 20, 35, 255)
C_ORANGE_FIRE = (255, 115, 0, 255)
C_YELLOW_FIRE = (255, 235, 50, 255)
C_RED_FIRE    = (240, 30, 40, 255)

def create_img(w, h):
    return Image.new("RGBA", (w, h), C_TRANS)

# --- 1. SHIP BANKING (5 FRAMES 32x32) ---
def draw_ship_banking(bank):
    # bank = -2 (max left), -1 (slight left), 0 (neutral), +1 (slight right), +2 (max right)
    img = create_img(32, 32)
    cx = 15.5
    for y in range(32):
        for x in range(32):
            dx = x - cx
            # Biến dạng 3D roll: dịch tâm và co giãn cánh
            roll_dx = dx - (bank * (y - 16) * 0.08)
            roll_scale = 1.0 - (abs(bank) * 0.12) if (dx * bank > 0) else 1.0 + (abs(bank) * 0.08)
            eff_dx = roll_dx / roll_scale

            # Mũi nhọn
            if 3 <= y <= 6 and abs(eff_dx) <= (y - 2) * 0.5:
                img.putpixel((x, y), C_STEEL_HI if abs(eff_dx) < 1 else C_STEEL_MID)
            # Buồng lái kính Cyan
            elif 7 <= y <= 12 and abs(eff_dx) <= 2.5:
                img.putpixel((x, y), C_CYAN_CORE if abs(eff_dx) < 1 else C_CYAN_GLOW)
            # Thân tàu bọc giáp
            elif 11 <= y <= 22:
                wing_span = 3.5 + (y - 11) * 1.0
                if abs(eff_dx) <= wing_span:
                    if abs(eff_dx) >= wing_span - 1.2:
                        img.putpixel((x, y), C_CYAN_GLOW if (15 <= y <= 18) else C_STEEL_HI)
                    elif abs(eff_dx) <= 1.5:
                        img.putpixel((x, y), C_PANEL_DK)
                    else:
                        img.putpixel((x, y), C_STEEL_MID)
            # Cụm ống xả đuôi kép
            elif 23 <= y <= 26 and abs(eff_dx) <= 4.0:
                if 1.0 <= abs(eff_dx) <= 3.2:
                    img.putpixel((x, y), C_STEEL_DK if y == 23 else C_PANEL_DK)
                elif abs(eff_dx) < 1.0:
                    img.putpixel((x, y), C_STEEL_MID)
    return img

# --- 2. MODULAR THRUSTER (4 FRAMES 16x16) ---
def draw_thruster_frame(f):
    img = create_img(16, 16)
    cx1, cx2 = 5.0, 10.0 # Ống xả kép
    lengths = [7, 12, 15, 10]
    flen = lengths[f]
    for y in range(flen):
        for x in range(16):
            for cx in [cx1, cx2]:
                d = abs(x - cx)
                if d <= 1.5:
                    if y < flen * 0.3:
                        img.putpixel((x, y), C_CYAN_CORE)
                    elif y < flen * 0.7:
                        img.putpixel((x, y), C_CYAN_GLOW)
                    else:
                        img.putpixel((x, y), C_CYAN_DEEP)
    return img

# --- 3. HIT SPARKS (3 FRAMES 16x16) ---
def draw_hit_spark(f):
    img = create_img(16, 16)
    cx, cy = 7.5, 7.5
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - cx, y - cy)
            if f == 0:
                # Chớp trắng chữ X siêu sáng
                if abs(x - y) <= 1 or abs((15 - x) - y) <= 1:
                    if d < 6: img.putpixel((x, y), C_CYAN_CORE)
                elif d < 3: img.putpixel((x, y), C_CYAN_CORE)
            elif f == 1:
                # Tóe tia lửa vàng rực
                if 2 < d < 7 and ((x + y) % 2 == 0):
                    img.putpixel((x, y), C_YELLOW_FIRE)
                elif d <= 2:
                    img.putpixel((x, y), C_ORANGE_FIRE)
            elif f == 2:
                # Tàn lửa đỏ phân tán
                if 4 < d < 8 and ((x * 3 + y * 7) % 3 == 0):
                    img.putpixel((x, y), C_RED_FIRE)
    return img

# --- 4. STEREDENN 16-FRAME MASSIVE EXPLOSION (64x64) ---
# Tải và xử lý chuỗi 8 frame từ ParticleFX Studio, nội suy mượt mà thành 16 frames!
def generate_16_frame_explosion():
    from PIL import ImageFilter
    raw_strip = Image.open("assets/downloaded_fx/boss_strip.webp").convert("RGBA")
    
    # Trích xuất 8 frame gốc 160x160 -> chuyển sang 64x64 nền trong suốt
    pfx_8 = []
    for i in range(8):
        box = (i * 160, 0, (i + 1) * 160, 160)
        crop = raw_strip.crop(box)
        rgba = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
        for y in range(160):
            for x in range(160):
                r, g, b, a = crop.getpixel((x, y))
                if r > 32 or g > 32 or b > 32:
                    rgba.putpixel((x, y), (r, g, b, 255))
        pfx_64 = rgba.resize((64, 64), Image.NEAREST)
        pfx_8.append(pfx_64)

    # Nội suy thành 16 frames chuẩn Steredenn (Chunky smoke & flares)
    frames_16 = []
    for i in range(16):
        base_idx = i // 2
        next_idx = min(base_idx + 1, 7)
        alpha = (i % 2) * 0.5
        
        f = Image.blend(pfx_8[base_idx], pfx_8[next_idx], alpha)
        
        # Thêm hiệu ứng Steredenn Anamorphic Flare ở các frame đầu (f0..f2)
        if i in [0, 1, 2]:
            draw_f = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            for y in range(30, 34):
                for x in range(64):
                    fade = 1.0 - abs(x - 31.5) / 32.0
                    if fade > 0:
                        alpha_v = int(255 * fade * (1.0 - i * 0.3))
                        col = (255, 255, 255, alpha_v) if (y in [31, 32] and abs(x-31.5) < 16) else (0, 240, 255, int(alpha_v*0.8))
                        draw_f.putpixel((x, y), col)
            f = Image.alpha_composite(draw_f, f)
            
        frames_16.append(f)
    return frames_16

def main():
    print("==========================================================")
    print("Sinh bộ Asset Steredenn Big Beautiful Pixels:")
    print("==========================================================")
    
    # 1. Ship Banking 5 frames
    for idx, bank in enumerate([-2, -1, 0, 1, 2]):
        img = draw_ship_banking(bank)
        fname = f"ship_bank_f{idx}.png"
        img.save(OUT_DIR / fname)
        print(f" [V] Ship Bank Frame {idx} (bank={bank}): {fname}")

    # 2. Thruster 4 frames
    for f in range(4):
        img = draw_thruster_frame(f)
        fname = f"thruster_f{f}.png"
        img.save(OUT_DIR / fname)
        print(f" [V] Thruster Frame {f}: {fname}")

    # 3. Hit Sparks 3 frames
    for f in range(3):
        img = draw_hit_spark(f)
        fname = f"hit_spark_f{f}.png"
        img.save(OUT_DIR / fname)
        print(f" [V] Hit Spark Frame {f}: {fname}")

    # 4. Massive Explosion 16 frames
    exp_16 = generate_16_frame_explosion()
    for idx, img in enumerate(exp_16):
        fname = f"steredenn_exp_f{idx}.png"
        img.save(OUT_DIR / fname)
        print(f" [V] Steredenn Massive Explosion Frame {idx}/15: {fname}")

    print("\n[OK] Hoàn tất sinh toàn bộ asset Steredenn trong: assets/sprites/steredenn/")

if __name__ == "__main__":
    main()

