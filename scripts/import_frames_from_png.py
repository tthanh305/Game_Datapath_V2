#!/usr/bin/env python3
"""
Import modified PNG sprite files back into rtl/game/sprites_32x32.mem.
Reads from assets/sprites/extracted_frames/ (or custom path) and packs them
into the 32-tile memory format.
"""

import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MEM_PATH = ROOT / "rtl" / "game" / "sprites_32x32.mem"
FRAMES_DIR = ROOT / "assets" / "sprites" / "extracted_frames"

# 16-Color RGB palette lookup table for nearest-color matching
PALETTE_RGB = [
    (0x00, 0x00, 0x00),  # 0: Transparent (treated separately by alpha)
    (0x11, 0x11, 0x22),  # 1: DEEP_SPACE
    (0x22, 0x33, 0x44),  # 2: DARK_HULL
    (0x66, 0x77, 0x88),  # 3: STEEL_GREY
    (0xFF, 0xFF, 0xFF),  # 4: PURE_WHITE
    (0x33, 0xEE, 0xFF),  # 5: CYAN_NEON
    (0x22, 0x77, 0xFF),  # 6: BLUE_ENERGY
    (0xBB, 0x44, 0xFF),  # 7: PURPLE_SHLD
    (0xFF, 0x55, 0xAA),  # 8: PINK_ORB
    (0xFF, 0x33, 0x22),  # 9: RED_CRIMSON
    (0xFF, 0x99, 0x22),  # A: ORANGE_FIRE
    (0xFF, 0xEE, 0x66),  # B: YELLOW_GOLD
    (0x44, 0xFF, 0xCC),  # C: TEAL_MINT
    (0x22, 0x22, 0x11),  # D: NEBULA_DARK
    (0x44, 0x55, 0x22),  # E: NEBULA_MID
    (0x88, 0x77, 0x33),  # F: NEBULA_GOLD
]

def rgb_to_palette_idx(r, g, b, a):
    if a < 64:
        return 0  # Transparent
    best_idx = 1
    min_dist = float('inf')
    for idx in range(1, 16):
        pr, pg, pb = PALETTE_RGB[idx]
        dist = (r - pr)**2 + (g - pg)**2 + (b - pb)**2
        if dist < min_dist:
            min_dist = dist
            best_idx = idx
    return best_idx

def load_mem():
    lines = MEM_PATH.read_text().splitlines()
    return [int(line.strip(), 16) for line in lines if line.strip()]

def save_mem(pixels):
    lines = [f"{p & 0xF:01X}\n" for p in pixels]
    text = "".join(lines)
    # Save to all copies
    paths = [
        ROOT / "rtl" / "game" / "sprites_32x32.mem",
        ROOT / "sprites_32x32.mem",
        ROOT / "galaxian_steredenn_fpga_assets" / "sprites_32x32.mem",
    ]
    for p in paths:
        p.write_text(text)
    print(f"[OK] Đã cập nhật thành công {len(pixels)} pixel vào sprites_32x32.mem")

def write_32x32_tile(pixels, tile_idx, img_path):
    if not img_path.exists():
        return
    img = Image.open(img_path).convert("RGBA")
    if img.size != (32, 32):
        img = img.resize((32, 32), Image.NEAREST)
    offset = tile_idx * 1024
    for y in range(32):
        for x in range(32):
            r, g, b, a = img.getpixel((x, y))
            pixels[offset + y * 32 + x] = rgb_to_palette_idx(r, g, b, a)
    print(f" [V] Imported: {img_path.name} -> Tile {tile_idx:02d}")

def write_64x64_quad(pixels, base_tile_idx, img_path):
    if not img_path.exists():
        return
    img = Image.open(img_path).convert("RGBA")
    if img.size != (64, 64):
        img = img.resize((64, 64), Image.NEAREST)
    # 4 quadrants: TL (+0), TR (+1), BL (+2), BR (+3)
    quads = [(0, 0, 0), (32, 0, 1), (0, 32, 2), (32, 32, 3)]
    for qx, qy, q_offset in quads:
        t_idx = base_tile_idx + q_offset
        offset = t_idx * 1024
        for y in range(32):
            for x in range(32):
                r, g, b, a = img.getpixel((qx + x, qy + y))
                pixels[offset + y * 32 + x] = rgb_to_palette_idx(r, g, b, a)
    print(f" [V] Imported 64x64: {img_path.name} -> Tiles {base_tile_idx:02d}..{base_tile_idx+3:02d}")

def main():
    pixels = load_mem()
    
    # Check if user specified a folder or single file
    target_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else FRAMES_DIR
    print(f"Đang đọc sprite từ thư mục: {target_dir}")

    # 1. Player ship
    write_32x32_tile(pixels, 0,  target_dir / "player_ship_straight.png")
    write_32x32_tile(pixels, 16, target_dir / "player_ship_bank_left.png")
    write_32x32_tile(pixels, 20, target_dir / "player_ship_bank_right.png")
    
    # 2. Aliens
    write_32x32_tile(pixels, 1,  target_dir / "alien_elite_f0.png")
    write_32x32_tile(pixels, 17, target_dir / "alien_elite_f1.png")
    write_32x32_tile(pixels, 2,  target_dir / "alien_escort_f0.png")
    write_32x32_tile(pixels, 18, target_dir / "alien_escort_f1.png")
    write_32x32_tile(pixels, 3,  target_dir / "alien_drone_f0.png")
    write_32x32_tile(pixels, 19, target_dir / "alien_drone_f1.png")
    
    # 3. Shield & Explosions
    write_32x32_tile(pixels, 4,  target_dir / "energy_shield_ring.png")
    write_32x32_tile(pixels, 7,  target_dir / "explosion_stage0.png")
    write_32x32_tile(pixels, 8,  target_dir / "explosion_stage1.png")
    write_32x32_tile(pixels, 9,  target_dir / "explosion_stage2.png")
    write_32x32_tile(pixels, 10, target_dir / "explosion_stage3.png")
    write_32x32_tile(pixels, 11, target_dir / "laser_shockwave.png")
    
    # 4. 64x64 Sprites (Asteroid, Boss F0, Boss F1)
    write_64x64_quad(pixels, 12, target_dir / "asteroid_giant_64x64.png")
    write_64x64_quad(pixels, 24, target_dir / "boss_dreadnought_f0_64x64.png")
    write_64x64_quad(pixels, 28, target_dir / "boss_dreadnought_f1_64x64.png")
    
    save_mem(pixels)

if __name__ == "__main__":
    main()
