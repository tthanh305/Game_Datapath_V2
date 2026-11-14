#!/usr/bin/env python3
"""
Export all current sprites, frames, bosses, asteroids, player ships,
bullets, and VFX into high-res transparent PNGs and a combined Master Atlas sheet.
Outputs to:
  1. assets/sprites/extracted_frames/
  2. Artifact directory: C:/Users/thanh/.gemini/antigravity/brain/f6c0c5db-1b1d-474e-89e6-71cfbe17553e/
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MEM_PATH = ROOT / "rtl" / "game" / "sprites_32x32.mem"
REPO_OUT = ROOT / "assets" / "sprites" / "extracted_frames"
ARTIFACT_OUT = Path(r"C:\Users\thanh\.gemini\antigravity\brain\f6c0c5db-1b1d-474e-89e6-71cfbe17553e")

REPO_OUT.mkdir(parents=True, exist_ok=True)
ARTIFACT_OUT.mkdir(parents=True, exist_ok=True)

# 16-Color Master Palette (RGBA)
PALETTE_RGBA = {
    0x0: (0, 0, 0, 0),             # TRANSPARENT
    0x1: (0x11, 0x11, 0x22, 255),  # DEEP_SPACE / SHADOW
    0x2: (0x22, 0x33, 0x44, 255),  # DARK_HULL
    0x3: (0x66, 0x77, 0x88, 255),  # STEEL_GREY
    0x4: (0xFF, 0xFF, 0xFF, 255),  # PURE_WHITE
    0x5: (0x33, 0xEE, 0xFF, 255),  # CYAN_NEON
    0x6: (0x22, 0x77, 0xFF, 255),  # BLUE_ENERGY
    0x7: (0xBB, 0x44, 0xFF, 255),  # PURPLE_SHIELD
    0x8: (0xFF, 0x55, 0xAA, 255),  # PINK_ORB
    0x9: (0xFF, 0x33, 0x22, 255),  # RED_CRIMSON
    0xA: (0xFF, 0x99, 0x22, 255),  # ORANGE_FIRE
    0xB: (0xFF, 0xEE, 0x66, 255),  # YELLOW_GOLD
    0xC: (0x44, 0xFF, 0xCC, 255),  # TEAL_MINT
    0xD: (0x22, 0x22, 0x11, 255),  # NEBULA_DARK
    0xE: (0x44, 0x55, 0x22, 255),  # NEBULA_MID
    0xF: (0x88, 0x77, 0x33, 255),  # NEBULA_GOLD
}

def load_tiles():
    lines = MEM_PATH.read_text().splitlines()
    pixels = [int(line.strip(), 16) for line in lines if line.strip()]
    if len(pixels) != 32768:
        raise ValueError(f"Expected 32768 words, got {len(pixels)}")
    tiles = []
    for tid in range(32):
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        off = tid * 1024
        for y in range(32):
            for x in range(32):
                val = pixels[off + y * 32 + x]
                img.putpixel((x, y), PALETTE_RGBA[val])
        tiles.append(img)
    return tiles

def assemble_64x64(tl, tr, bl, br):
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    img.paste(tl, (0, 0))
    img.paste(tr, (32, 0))
    img.paste(bl, (0, 32))
    img.paste(br, (32, 32))
    return img

def render_projectiles_sheet():
    img = Image.new("RGBA", (192, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # 1. Player Main Bullets (Dual cyan/white)
    d.rectangle([10, 8, 13, 24], fill=(51, 238, 255, 255))
    d.rectangle([11, 10, 12, 22], fill=(255, 255, 255, 255))
    d.rectangle([18, 8, 21, 24], fill=(51, 238, 255, 255))
    d.rectangle([19, 10, 20, 22], fill=(255, 255, 255, 255))
    
    # 2. Player Homing Missile (Pink orb)
    d.ellipse([42, 10, 52, 20], fill=(255, 85, 170, 255), outline=(255, 255, 255, 255))
    
    # 3. Enemy Sniper (Cyan Needle)
    d.rectangle([76, 6, 79, 26], fill=(51, 238, 255, 255), outline=(255, 255, 255, 255))
    
    # 4. Enemy Seeker (Teal plasma)
    d.ellipse([104, 10, 116, 22], fill=(68, 255, 204, 255), outline=(255, 255, 255, 255))
    
    # 5. Enemy Wave (Purple blast)
    d.ellipse([136, 11, 146, 21], fill=(187, 68, 255, 255), outline=(255, 255, 255, 255))
    
    # 6. Enemy Fireball (Crimson pellet)
    d.ellipse([166, 11, 176, 21], fill=(255, 51, 34, 255), outline=(255, 153, 34, 255))
    
    return img

import sys
sys.path.insert(0, str(ROOT))
from scripts.design_boss2_pixelart import (
    generate_carrier_hull, generate_turret_sprite,
    generate_dead_turret, generate_core_frame, generate_hangar_door
)

def render_void_carrier_boss():
    # Assembles the 128x64 Void Carrier Leviathan Flagship (Pixel Art)
    hull = generate_carrier_hull()
    door = generate_hangar_door(open_state=False)
    core = generate_core_frame(0)
    turret = generate_turret_sprite(recoil=0)

    comp = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    # 1. Main Hull
    comp.paste(hull, (0, 0), hull)
    # 2. Hangar Door
    comp.paste(door, (42, 24), door)
    # 3. Core
    comp.paste(core, (48, 16), core)
    # 4. Left Turret
    comp.paste(turret, (0, 4), turret)
    # 5. Right Turret
    comp.paste(turret, (96, 4), turret)
    return comp

def scale_up(img, factor=4):
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)

def main():
    tiles = load_tiles()
    
    # Dictionary of all individual sprites
    sprites = {}
    
    # Player ships & gear
    sprites["player_ship_straight"] = tiles[0]
    sprites["player_ship_bank_left"] = tiles[16]
    sprites["player_ship_bank_right"] = tiles[20]
    sprites["player_shield_ring"] = tiles[4]
    sprites["laser_shockwave_ring"] = tiles[11]
    
    # 4-Frame Formation Aliens
    sprites["alien_row0_elite_f0"] = tiles[1]
    sprites["alien_row0_elite_f1"] = tiles[17]
    sprites["alien_row0_elite_f2"] = tiles[21]
    
    sprites["alien_row1_escort_f0"] = tiles[2]
    sprites["alien_row1_escort_f1"] = tiles[18]
    sprites["alien_row1_escort_f2"] = tiles[22]
    
    sprites["alien_row2_drone_f0"] = tiles[3]
    sprites["alien_row2_drone_f1"] = tiles[19]
    sprites["alien_row2_drone_f2"] = tiles[23]
    
    # Explosions
    sprites["explosion_stage0"] = tiles[7]
    sprites["explosion_stage1"] = tiles[8]
    sprites["explosion_stage2"] = tiles[9]
    sprites["explosion_stage3"] = tiles[10]
    
    # Asteroids
    sprites["asteroid_small_32x32"] = tiles[5]
    asteroid_64 = assemble_64x64(tiles[12], tiles[13], tiles[14], tiles[15])
    sprites["asteroid_giant_64x64"] = asteroid_64
    
    # Boss 1: Dreadnought
    boss1_f0 = assemble_64x64(tiles[24], tiles[25], tiles[26], tiles[27])
    boss1_f1 = assemble_64x64(tiles[28], tiles[29], tiles[30], tiles[31])
    sprites["boss1_dreadnought_f0_64x64"] = boss1_f0
    sprites["boss1_dreadnought_f1_64x64"] = boss1_f1
    
    # Boss 2: Void Carrier
    carrier_boss = render_void_carrier_boss()
    sprites["boss2_void_carrier_128x64"] = carrier_boss
    
    # Projectiles sheet
    projectiles = render_projectiles_sheet()
    sprites["projectiles_and_bullets"] = projectiles
    
    # Subtiles from Tile 6
    t6 = tiles[6]
    sprites["muzzle_flash_16x16"] = t6.crop((0, 0, 16, 16))
    sprites["item_power_P_16x16"] = t6.crop((16, 0, 32, 16))
    sprites["item_shield_S_16x16"] = t6.crop((0, 16, 16, 32))
    sprites["item_rage_R_16x16"] = t6.crop((16, 16, 32, 32))
    
    # Save individual scaled images to both directories
    for name, img in sprites.items():
        # Native size
        img.save(REPO_OUT / f"{name}.png")
        # Scaled 4x for high-DPI viewing in artifacts
        scale = 2 if img.width >= 128 else 4
        scaled = scale_up(img, scale)
        scaled.save(ARTIFACT_OUT / f"{name}_x{scale}.png")
        scaled.save(REPO_OUT / f"{name}_x{scale}.png")

    # =========================================================================
    # CREATE COMPREHENSIVE SPRITE ATLAS POSTER (game_sprites_atlas.png)
    # =========================================================================
    ATLAS_W = 1000
    ATLAS_H = 750
    atlas = Image.new("RGBA", (ATLAS_W, ATLAS_H), (10, 12, 24, 255))
    d = ImageDraw.Draw(atlas)
    
    # Grid lines / Background stars
    for gx in range(0, ATLAS_W, 40):
        d.line([(gx, 0), (gx, ATLAS_H)], fill=(20, 24, 42, 255))
    for gy in range(0, ATLAS_H, 40):
        d.line([(0, gy), (ATLAS_W, gy)], fill=(20, 24, 42, 255))
        
    d.rectangle([10, 10, ATLAS_W - 10, ATLAS_H - 10], outline=(40, 70, 110, 255), width=2)
    
    def paste_scaled(img, x, y, scale=2):
        s = scale_up(img, scale)
        atlas.paste(s, (x, y), s)

    # Section 1: Player Ships & Items (Top Left)
    d.text((30, 25), "[1] TAU CHINH (PLAYER SHIPS & GEAR)", fill=(51, 238, 255, 255))
    paste_scaled(sprites["player_ship_straight"], 30, 50, 2)
    paste_scaled(sprites["player_ship_bank_left"], 110, 50, 2)
    paste_scaled(sprites["player_ship_bank_right"], 190, 50, 2)
    paste_scaled(sprites["player_shield_ring"], 270, 50, 2)
    
    d.text((355, 25), "ITEMS & FLASH", fill=(255, 238, 102, 255))
    paste_scaled(sprites["muzzle_flash_16x16"], 355, 55, 3)
    paste_scaled(sprites["item_power_P_16x16"], 415, 55, 3)
    paste_scaled(sprites["item_shield_S_16x16"], 475, 55, 3)
    paste_scaled(sprites["item_rage_R_16x16"], 535, 55, 3)
    
    # Section 2: Bullets & Projectiles
    d.text((620, 25), "[2] HE THONG DAN (PROJECTILES)", fill=(68, 255, 204, 255))
    paste_scaled(sprites["projectiles_and_bullets"], 620, 55, 2)

    # Section 3: Quai vat 4-Frame Flap Animation
    d.text((30, 135), "[3] QUAN DICH (ALIEN FORMATION - 4-FRAME ANIMATION)", fill=(255, 85, 170, 255))
    
    # Row 0 Elite
    d.text((30, 160), "Row 0: Elite (Wings Open -> Flap Down -> Hyper-Extended):", fill=(200, 200, 200, 255))
    paste_scaled(sprites["alien_row0_elite_f0"], 30, 180, 2)
    paste_scaled(sprites["alien_row0_elite_f1"], 110, 180, 2)
    paste_scaled(sprites["alien_row0_elite_f2"], 190, 180, 2)
    
    # Row 1 Escort
    d.text((320, 160), "Row 1: Escort (Mandibles Flare & Swept):", fill=(200, 200, 200, 255))
    paste_scaled(sprites["alien_row1_escort_f0"], 320, 180, 2)
    paste_scaled(sprites["alien_row1_escort_f1"], 400, 180, 2)
    paste_scaled(sprites["alien_row1_escort_f2"], 480, 180, 2)

    # Row 2/3 Drone
    d.text((610, 160), "Row 2/3: Drone (Tendrils Pulse):", fill=(200, 200, 200, 255))
    paste_scaled(sprites["alien_row2_drone_f0"], 610, 180, 2)
    paste_scaled(sprites["alien_row2_drone_f1"], 690, 180, 2)
    paste_scaled(sprites["alien_row2_drone_f2"], 770, 180, 2)
    
    # Section 4: Thien thach
    d.text((30, 270), "[4] THIEN THACH (ASTEROIDS 32x32px & 64x64px)", fill=(255, 153, 34, 255))
    d.text((30, 295), "32x32px (6 HP, quay nhe):", fill=(180, 180, 180, 255))
    paste_scaled(sprites["asteroid_small_32x32"], 30, 315, 2)
    
    d.text((160, 295), "64x64px (14 HP, Magma Cratered Rock):", fill=(180, 180, 180, 255))
    paste_scaled(sprites["asteroid_giant_64x64"], 160, 315, 2)
    
    # Section 5: Explosions
    d.text((450, 270), "[5] VU NO DIEN ANH (EXPLOSION STAGES)", fill=(255, 238, 102, 255))
    paste_scaled(sprites["explosion_stage0"], 450, 315, 2)
    paste_scaled(sprites["explosion_stage1"], 530, 315, 2)
    paste_scaled(sprites["explosion_stage2"], 610, 315, 2)
    paste_scaled(sprites["explosion_stage3"], 690, 315, 2)
    paste_scaled(sprites["laser_shockwave_ring"], 770, 315, 2)
    
    # Section 6: Bosses
    d.text((30, 480), "[6] BOSS MOTHERSHIP & MODULAR CARRIER HANGAR", fill=(255, 51, 34, 255))
    
    d.text((30, 505), "Boss 1: Dreadnought Mothership (Wave 5, 64x64px, 2-Frame):", fill=(200, 200, 200, 255))
    paste_scaled(sprites["boss1_dreadnought_f0_64x64"], 30, 530, 2)
    paste_scaled(sprites["boss1_dreadnought_f1_64x64"], 180, 530, 2)
    
    d.text((400, 505), "Boss 2: Modular Void Carrier Hangar (Wave 10, 128x64px, Dual Aiming Turrets):", fill=(200, 200, 200, 255))
    paste_scaled(sprites["boss2_void_carrier_128x64"], 400, 530, 2)

    # Save Master Atlas
    atlas.save(ARTIFACT_OUT / "game_sprites_atlas.png")
    atlas.save(REPO_OUT / "game_sprites_atlas.png")
    
    print(f"[OK] Master Sprite Atlas generated at:\n  - {ARTIFACT_OUT / 'game_sprites_atlas.png'}\n  - {REPO_OUT / 'game_sprites_atlas.png'}")

if __name__ == "__main__":
    main()
