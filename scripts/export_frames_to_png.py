#!/usr/bin/env python3
"""
Export all 32 tiles and individual sprites/frames from rtl/game/sprites_32x32.mem
into clean, editable 32x32 and 64x64 PNG files with transparency.
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MEM_PATH = ROOT / "rtl" / "game" / "sprites_32x32.mem"
OUT_DIR = ROOT / "assets" / "sprites" / "extracted_frames"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# 16-Color Master Palette (RGBA, index 0 is fully transparent)
PALETTE_RGBA = {
    0x0: (0, 0, 0, 0),          # TRANSPARENT
    0x1: (0x11, 0x11, 0x22, 255),  # DEEP_SPACE
    0x2: (0x22, 0x33, 0x44, 255),  # DARK_HULL
    0x3: (0x66, 0x77, 0x88, 255),  # STEEL_GREY
    0x4: (0xFF, 0xFF, 0xFF, 255),  # PURE_WHITE
    0x5: (0x33, 0xEE, 0xFF, 255),  # CYAN_NEON
    0x6: (0x22, 0x77, 0xFF, 255),  # BLUE_ENERGY
    0x7: (0xBB, 0x44, 0xFF, 255),  # PURPLE_SHLD
    0x8: (0xFF, 0x55, 0xAA, 255),  # PINK_ORB
    0x9: (0xFF, 0x33, 0x22, 255),  # RED_CRIMSON
    0xA: (0xFF, 0x99, 0x22, 255),  # ORANGE_FIRE
    0xB: (0xFF, 0xEE, 0x66, 255),  # YELLOW_GOLD
    0xC: (0x44, 0xFF, 0xCC, 255),  # TEAL_MINT
    0xD: (0x22, 0x22, 0x11, 255),  # NEBULA_DARK
    0xE: (0x44, 0x55, 0x22, 255),  # NEBULA_MID
    0xF: (0x88, 0x77, 0x33, 255),  # NEBULA_GOLD
}

def load_mem():
    lines = MEM_PATH.read_text().splitlines()
    pixels = [int(line.strip(), 16) for line in lines if line.strip()]
    if len(pixels) != 32768:
        raise ValueError(f"Expected 32768 pixels in {MEM_PATH}, got {len(pixels)}")
    return pixels

def extract_tile(pixels, tile_idx):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    offset = tile_idx * 1024
    for y in range(32):
        for x in range(32):
            val = pixels[offset + y * 32 + x]
            img.putpixel((x, y), PALETTE_RGBA[val])
    return img

def assemble_64x64(tl, tr, bl, br):
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    img.paste(tl, (0, 0))
    img.paste(tr, (32, 0))
    img.paste(bl, (0, 32))
    img.paste(br, (32, 32))
    return img

def main():
    pixels = load_mem()
    tiles = [extract_tile(pixels, i) for i in range(32)]
    
    # 1. Export 32 raw tiles (tile_00.png .. tile_31.png)
    raw_dir = OUT_DIR / "raw_tiles"
    raw_dir.mkdir(exist_ok=True)
    for i, t in enumerate(tiles):
        t.save(raw_dir / f"tile_{i:02d}.png")
        
    # 2. Export named friendly files for easy editing
    named_sprites = {
        # Player ship
        "player_ship_straight.png": tiles[0],
        "player_ship_bank_left.png": tiles[16],
        "player_ship_bank_right.png": tiles[20],
        # Shield & Shockwave
        "energy_shield_ring.png": tiles[4],
        "laser_shockwave.png": tiles[11],
        # Formation Aliens (Frame 0 & Frame 1)
        "alien_elite_f0.png": tiles[1],
        "alien_elite_f1.png": tiles[17],
        "alien_escort_f0.png": tiles[2],
        "alien_escort_f1.png": tiles[18],
        "alien_drone_f0.png": tiles[3],
        "alien_drone_f1.png": tiles[19],
        # Explosions (4 stages)
        "explosion_stage0.png": tiles[7],
        "explosion_stage1.png": tiles[8],
        "explosion_stage2.png": tiles[9],
        "explosion_stage3.png": tiles[10],
    }
    
    for name, img in named_sprites.items():
        img.save(OUT_DIR / name)
        
    # 3. Assemble and export Native 64x64 sprites (Boss & Asteroid)
    asteroid_64 = assemble_64x64(tiles[12], tiles[13], tiles[14], tiles[15])
    asteroid_64.save(OUT_DIR / "asteroid_giant_64x64.png")
    
    boss_f0_64 = assemble_64x64(tiles[24], tiles[25], tiles[26], tiles[27])
    boss_f0_64.save(OUT_DIR / "boss_dreadnought_f0_64x64.png")
    
    boss_f1_64 = assemble_64x64(tiles[28], tiles[29], tiles[30], tiles[31])
    boss_f1_64.save(OUT_DIR / "boss_dreadnought_f1_64x64.png")
    
    # 4. Extract 16x16 sub-tiles from Tile 6 (Flash & Capsules)
    t6 = tiles[6]
    t6.crop((0, 0, 16, 16)).save(OUT_DIR / "muzzle_flash_16x16.png")
    t6.crop((16, 0, 32, 16)).save(OUT_DIR / "item_power_P_16x16.png")
    t6.crop((0, 16, 16, 32)).save(OUT_DIR / "item_shield_S_16x16.png")
    t6.crop((16, 16, 32, 32)).save(OUT_DIR / "item_rage_R_16x16.png")

    print(f"[OK] Đã xuất toàn bộ frame thành công vào thư mục:\n     {OUT_DIR}")

if __name__ == "__main__":
    main()
