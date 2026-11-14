#!/usr/bin/env python3
"""
Generate 32-Tile (32x32x4-bit = 32,768 words) Enhanced Sprite & VFX BRAM Bank
for Galaxian x Steredenn Arcade Shmup (FPGA Hardware Edition).

Tile Map (5-bit tile_id[4:0]):
  00 (0x00): Player Interceptor Fighter - Straight (32x32)
  01 (0x01): Row 0 Elite Alien - Frame 0 (Wings Open)
  02 (0x02): Row 1 Escort Alien - Frame 0 (Blades Open)
  03 (0x03): Row 2/3 Drone Alien - Frame 0 (Claws Open)
  04 (0x04): Hexagonal Energy Shield Ring + Twin Gun-Pods (32x32)
  05 (0x05): Asteroid 32x32 (Legacy fallback)
  06 (0x06): 4x 16x16 Sub-tiles:
             - Top-Left (0,0):     Starburst Muzzle Flash
             - Top-Right (0,1):    Item [P] Power-Up Capsule
             - Bottom-Left (1,0):  Item [S] Shield Capsule
             - Bottom-Right (1,1): Item [R] Rage/Laser Capsule
  07..10:    4-Stage Explosion Animation (32x32)
  11 (0x0B): Overdrive Laser Emitter Shockwave Ring (32x32)
  12..15:    Native 64x64 Giant Cratered & Magma Asteroid (TL=12, TR=13, BL=14, BR=15)
  16 (0x10): Player Interceptor Fighter - Bank Left (32x32)
  17 (0x11): Row 0 Elite Alien - Frame 1 (Wings Flapped Down)
  18 (0x12): Row 1 Escort Alien - Frame 1 (Blades Swept In)
  19 (0x13): Row 2/3 Drone Alien - Frame 1 (Tentacles Pulsed)
  20 (0x14): Player Interceptor Fighter - Bank Right (32x32)
  21..23:    Extra VFX / Decorative Emblem Tiles
  24..27:    Native 64x64 Dreadnought Mothership Boss - Frame 0 (TL=24, TR=25, BL=26, BR=27)
  28..31:    Native 64x64 Dreadnought Mothership Boss - Frame 1 (TL=28, TR=29, BL=30, BR=31)
"""

import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# 16-Color Master Palette (matches palette_lut.vh)
PALETTE_RGB = {
    0x0: (0x00, 0x00, 0x00),  # TRANSPARENT
    0x1: (0x11, 0x11, 0x22),  # DEEP_SPACE
    0x2: (0x22, 0x33, 0x44),  # DARK_HULL
    0x3: (0x66, 0x77, 0x88),  # STEEL_GREY
    0x4: (0xFF, 0xFF, 0xFF),  # PURE_WHITE
    0x5: (0x33, 0xEE, 0xFF),  # CYAN_NEON
    0x6: (0x22, 0x77, 0xFF),  # BLUE_ENERGY
    0x7: (0xBB, 0x44, 0xFF),  # PURPLE_SHLD
    0x8: (0xFF, 0x55, 0xAA),  # PINK_ORB
    0x9: (0xFF, 0x33, 0x22),  # RED_CRIMSON
    0xA: (0xFF, 0x99, 0x22),  # ORANGE_FIRE
    0xB: (0xFF, 0xEE, 0x66),  # YELLOW_GOLD
    0xC: (0x44, 0xFF, 0xCC),  # TEAL_MINT
    0xD: (0x22, 0x22, 0x11),  # NEBULA_DARK
    0xE: (0x44, 0x55, 0x22),  # NEBULA_MID
    0xF: (0x88, 0x77, 0x33),  # NEBULA_GOLD
}


def new_grid(w=32, h=32):
    return [[0 for _ in range(w)] for _ in range(h)]


def set_px(g, x, y, c):
    h = len(g)
    w = len(g[0])
    if 0 <= x < w and 0 <= y < h:
        g[y][x] = c & 0xF


def set_sym(g, y, dx, c, cx=16):
    set_px(g, cx - 1 - dx, y, c)
    set_px(g, cx + dx, y, c)


# =============================================================================
# 1. PLAYER INTERCEPTOR FIGHTER (Tiles 0=Straight, 16=Bank Left, 20=Bank Right)
# =============================================================================
def make_player_ship(bank=0):
    # bank: 0=straight, -1=left bank, +1=right bank
    g = new_grid(32, 32)
    # Preserve tb_shooter check: rom[16] == 4'h4 on Tile 0 (y=0, x=16)
    if bank == 0:
        set_px(g, 15, 0, 0x4)
        set_px(g, 16, 0, 0x4)

    for y in range(1, 30):
        for x in range(32):
            # Center reference shifted slightly during banking
            cx = 15.5 + (bank * (y - 14) * 0.06)
            dx = x - cx
            # Asymmetric wing foreshortening for 3D roll
            if bank < 0:
                eff_dx = dx / (0.78 if dx < 0 else 1.16)
            elif bank > 0:
                eff_dx = dx / (1.16 if dx < 0 else 0.78)
            else:
                eff_dx = dx
            adx = abs(eff_dx)
            # Lighting bias: raised wing gets brighter highlight
            lit_side = (dx > 0 and bank < 0) or (dx < 0 and bank > 0)

            # Nose tip & forward laser lance (y = 1..5)
            if 1 <= y <= 5:
                half_w = 0.8 + (y - 1) * 0.35
                if adx <= half_w:
                    set_px(g, x, y, 0x4 if adx < 0.9 else 0x5)
            # Glass Canopy & Upper Fuselage (y = 6..12)
            elif 6 <= y <= 12:
                if adx <= 1.2 and 7 <= y <= 11:
                    set_px(g, x, y, 0x4 if y <= 9 else 0x5)
                elif adx <= 2.3 and 6 <= y <= 12:
                    set_px(g, x, y, 0x5 if (7 <= y <= 10) else 0x4)
                elif adx <= 3.6:
                    set_px(g, x, y, 0x4 if lit_side else 0x3)
                elif adx <= 4.5 and y >= 9:
                    set_px(g, x, y, 0x2)
            # Swept Delta Wings + Twin Wing-Mounted Railguns (y = 13..23)
            elif 13 <= y <= 23:
                span = 4.5 + (y - 12) * 0.95
                # Outer wingtip railgun pods at adx in [11.5 .. 13.8]
                if 15 <= y <= 23 and 11.2 <= adx <= 13.6:
                    if y in (15, 16):
                        set_px(g, x, y, 0x5)
                    elif adx >= 12.6:
                        set_px(g, x, y, 0x2)
                    else:
                        set_px(g, x, y, 0x4 if lit_side else 0x3)
                elif adx <= span:
                    if adx <= 1.4:
                        set_px(g, x, y, 0x4 if y in (14, 15) else 0x6)
                    elif adx <= 2.8:
                        set_px(g, x, y, 0x3)
                    elif abs(adx - (span - 1.2)) <= 0.8:
                        # Glowing cyan plasma channel along leading wing edge
                        set_px(g, x, y, 0x5 if (y % 2 == 0 or lit_side) else 0x6)
                    elif adx >= span - 0.6:
                        set_px(g, x, y, 0x4)
                    elif 18 <= y <= 21 and 5.0 <= adx <= 7.5:
                        set_px(g, x, y, 0x6 if y == 19 else 0x2)
                    else:
                        set_px(g, x, y, 0x3 if (lit_side or y < 19) else 0x2)
            # Rear Twin Thruster Shroud & Exhaust Glow (y = 24..29)
            elif 24 <= y <= 26:
                if adx <= 1.2:
                    set_px(g, x, y, 0x2)
                elif 1.3 <= adx <= 3.8:
                    set_px(g, x, y, 0x4 if y == 26 else 0x3)
                elif 5.5 <= adx <= 8.5 and y <= 25:
                    set_px(g, x, y, 0x2)
            elif 27 <= y <= 29:
                if adx <= 1.3:
                    set_px(g, x, y, 0x4 if y == 27 else 0xB)
                elif adx <= 2.6 and y <= 28:
                    set_px(g, x, y, 0xA if y == 27 else 0x9)
    return g


# =============================================================================
# 2. ROW 0 ELITE ALIEN (Tile 1 = Frame 0, Tile 17 = Frame 1)
# =============================================================================
def make_elite_alien(frame=0):
    g = new_grid(32, 32)
    wing_drop = 4 if frame == 2 else (2 if frame == 1 else 0)
    claw_in = 2 if frame == 2 else (1 if frame == 1 else 0)

    for y in range(3, 29):
        for dx in range(16):
            # Crown horns & psychic crest (y = 3..7)
            if 3 <= y <= 7:
                horn_x = 4 + (7 - y)
                if dx in (horn_x, horn_x + 1):
                    set_sym(g, y, dx, 0x5 if (frame == 2 and y in (4, 5)) else (0x8 if dx == horn_x else 0x7))
                elif y >= 6 and dx <= 3:
                    set_sym(g, y, dx, 0x4 if (frame == 2 and y == 6) else (0xB if (y == 6 and dx <= 1) else 0x8))
            # Armored Head & Glowing Eyes (y = 8..13)
            # Note: tb_shooter checks rom[1024 + 8*32 + 16] != 0 -> (y=8, dx=0) must be non-zero!
            elif 8 <= y <= 13:
                if 10 <= y <= 12 and dx in (2, 3):
                    set_sym(g, y, dx, 0x4 if (frame == 2 or dx == 2) else 0x5)  # Glowing cyan/white eyes
                elif dx <= 5:
                    set_sym(g, y, dx, 0x8 if (dx <= 2 or y == 8) else 0x7)
                # Swept bio-mechanical wings
                wy = y - wing_drop
                max_wing_dx = 14 if frame == 2 else (11 if frame == 1 else 13)
                if 7 <= wy <= 13 and 6 <= dx <= max_wing_dx:
                    if dx >= max_wing_dx - 2:
                        set_sym(g, y, dx, 0x4 if (frame == 2 and y in (9, 10)) else (0x5 if y in (9, 10) else 0x8))
                    else:
                        set_sym(g, y, dx, 0x7 if (dx + y) % 2 == 0 else 0x2)
            # Core Thorax & Lower Wing Blades (y = 14..21)
            elif 14 <= y <= 21:
                if dx <= 1 and 15 <= y <= 18:
                    core_c = 0x4 if frame == 2 else (0x4 if (frame == 1 and y == 16) else 0xB)
                    set_sym(g, y, dx, core_c)  # Golden energy core flash
                elif dx <= 4:
                    set_sym(g, y, dx, 0x8 if dx <= 2 else 0x7)
                elif 5 <= dx <= (15 if frame == 2 else (14 if frame == 1 else 12)) and y <= (19 + wing_drop):
                    if dx >= (14 if frame == 2 else (13 if frame == 1 else 11)):
                        set_sym(g, y, dx, 0x8)
                    elif dx >= 9:
                        set_sym(g, y, dx, 0x3 if y % 2 == 0 else 0x2)
                    else:
                        set_sym(g, y, dx, 0x7)
            # Articulated Pincer Legs (y = 22..28)
            elif 22 <= y <= 28:
                leg_x = 2 + (y - 22) - claw_in
                if dx in (leg_x, leg_x + 1):
                    set_sym(g, y, dx, 0x4 if (frame == 2 and y >= 26) else (0xA if y >= 26 else 0x8))
                elif y <= 24 and dx <= 1:
                    set_sym(g, y, dx, 0x7)
    return g


# =============================================================================
# 3. ROW 1 ESCORT ALIEN (Tile 2 = Frame 0, Tile 18 = Frame 1, Tile 22 = Frame 2)
# =============================================================================
def make_escort_alien(frame=0):
    g = new_grid(32, 32)
    wing_flare = 2 if frame == 2 else (1 if frame == 1 else 0)
    for y in range(3, 28):
        for dx in range(16):
            # Twin Plasma Horns (y = 3..7)
            if 3 <= y <= 7:
                if (4 - wing_flare) <= dx <= (7 - wing_flare):
                    set_sym(g, y, dx, 0x4 if (frame == 2 and y <= 4) else (0xB if y <= 4 else 0xA))
                elif y >= 6 and dx <= 3:
                    set_sym(g, y, dx, 0xA)
            # Visor Eyes & Crimson Carapace (y = 8..14)
            elif 8 <= y <= 14:
                if 10 <= y <= 12 and dx in (2, 3):
                    set_sym(g, y, dx, 0x4)
                elif dx <= 5:
                    set_sym(g, y, dx, 0xA if dx <= 3 else 0x9)
                elif 6 <= dx <= (11 + wing_flare):
                    if dx >= (10 + wing_flare):
                        set_sym(g, y, dx, 0x4 if frame == 2 else (0xA if frame == 1 else 0x3))
                    else:
                        set_sym(g, y, dx, 0x2)
            # Forward-Swept Scythe Wings & Core (y = 15..21)
            elif 15 <= y <= 21:
                if dx <= 1 and 16 <= y <= 18:
                    set_sym(g, y, dx, 0x4 if frame >= 1 else 0xB)
                elif dx <= 3:
                    set_sym(g, y, dx, 0xA)
                elif 4 <= dx <= (9 - (y - 15) // 2 + wing_flare):
                    set_sym(g, y, dx, 0x9 if dx <= 6 else 0x2)
            # Twin Scythe Talons (y = 22..27)
            elif 22 <= y <= 27:
                tx = (5 if frame == 2 else (4 if frame == 0 else 2)) + (y - 22) // 2
                if dx in (tx, tx + 1):
                    set_sym(g, y, dx, 0x4 if (frame == 2 and y >= 25) else (0x9 if y >= 25 else 0xA))
                elif y <= 23 and dx <= 1:
                    set_sym(g, y, dx, 0x4)
    return g


# =============================================================================
# 4. ROW 2/3 DRONE ALIEN (Tile 3 = Frame 0, Tile 19 = Frame 1, Tile 23 = Frame 2)
# =============================================================================
def make_drone_alien(frame=0):
    g = new_grid(32, 32)
    pulse = 2 if frame == 2 else (1 if frame == 1 else 0)
    for y in range(3, 27):
        for dx in range(16):
            # Rounded Cyber Saucer Dome (y = 3..9)
            if 3 <= y <= 9:
                max_dx = int(math.sqrt(max(0, 81 - (10 - y) * (10 - y))))
                if dx <= max_dx:
                    if y <= 5:
                        set_sym(g, y, dx, 0x4 if (frame == 2 and y <= 4) else 0xC)
                    elif 7 <= y <= 9 and dx <= 3:
                        set_sym(g, y, dx, 0x4 if (y == 7 or frame == 2) else 0x6)
                    else:
                        set_sym(g, y, dx, 0x5 if dx <= max_dx - 2 else 0xC)
            # Wide Saucer Rim & Glowing Wing Pods (y = 10..17)
            elif 10 <= y <= 17:
                if 10 <= y <= 12 and dx <= 3:
                    set_sym(g, y, dx, 0x4 if frame == 2 else (0x6 if y <= 11 else 0x4))
                elif dx <= 8:
                    set_sym(g, y, dx, 0x5 if (y + dx + pulse) % 3 != 0 else 0xC)
                elif dx <= (11 + pulse) and 12 <= y <= 16:
                    set_sym(g, y, dx, 0x4 if (frame == 2 and dx >= 11) else (0x5 if (frame == 1 and dx == 12) else (0x3 if dx == 9 else 0x2)))
            # Lower Thruster Skirt & Mechanical Tentacles (y = 18..26)
            elif 18 <= y <= 20:
                if dx <= 5:
                    set_sym(g, y, dx, 0xC if dx <= 2 else 0x5)
            elif 21 <= y <= 26:
                leg_dx = (1 if frame == 2 else (2 if frame == 1 else 3)) + (y - 21) // 2
                if dx in (leg_dx, leg_dx + 1):
                    set_sym(g, y, dx, 0x4 if (frame >= 1 and y == 26) else 0xC)
                elif y <= 23 and dx == 0:
                    set_sym(g, y, dx, 0x4 if frame == 2 else (0x5 if frame == 1 else 0x6))
    return g


# =============================================================================
# 5. TILE 4: HEXAGONAL ENERGY SHIELD FORCEFIELD + SIDE GUN-PODS (32x32)
# =============================================================================
def make_shield_ring():
    g = new_grid(32, 32)
    cx, cy = 15.5, 15.5
    for y in range(32):
        for x in range(32):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            # Outer plasma barrier ring with front specular highlight
            if 12.6 <= d <= 15.3:
                if dy < -9.5 and abs(dx) < 6:
                    set_px(g, x, y, 0x4 if d < 14.0 else 0x5)
                elif 13.4 <= d <= 14.4:
                    set_px(g, x, y, 0x8 if (x + y) % 2 == 0 else 0x7)
                else:
                    set_px(g, x, y, 0x7)
            # Subtle inner hexagonal lattice nodes
            elif 9.5 <= d < 12.6 and ((x % 4 == 0 and y % 4 == 0) or (x % 4 == 2 and y % 4 == 2)):
                if dy < -4:
                    set_px(g, x, y, 0x5)
            # Twin floating phase-gun pods inside shield
            if 10 <= y <= 13 and abs(abs(dx) - 4.5) <= 1.5:
                set_px(g, x, y, 0x4 if abs(abs(dx) - 4.0) < 0.8 else 0x8)
    return g


# =============================================================================
# 6. TILE 6: 4 SUB-TILES 16x16 (MUZZLE FLASH + ITEMS [P], [S], [R])
# =============================================================================
LETTER_5X7 = {
    "P": [
        "11110",
        "10001",
        "10001",
        "11110",
        "10000",
        "10000",
        "10000",
    ],
    "S": [
        "01111",
        "10000",
        "10000",
        "01110",
        "00001",
        "00001",
        "11110",
    ],
    "R": [
        "11110",
        "10001",
        "10001",
        "11110",
        "10100",
        "10010",
        "10001",
    ],
}


def draw_item_subtile(g, ox, oy, letter, border_hi, border_lo, glyph_col):
    # 14x14 beveled sci-fi capsule inside 16x16 subtile (1..14, 1..14)
    for y in range(1, 15):
        for x in range(1, 15):
            # Cut 1px corners for octagonal arcade capsule look
            if (x in (1, 14)) and (y in (1, 14)):
                continue
            is_outer = (x in (1, 14)) or (y in (1, 14)) or (x in (2, 13) and y in (2, 13))
            is_inner_rim = (x in (2, 13)) or (y in (2, 13))
            if is_outer:
                set_px(g, ox + x, oy + y, 0x4 if (x + y < 10) else border_hi)
            elif is_inner_rim:
                set_px(g, ox + x, oy + y, border_lo)
            else:
                set_px(g, ox + x, oy + y, 0x2 if (x + y) % 2 == 0 else 0x1)
    # Draw crisp 5x7 letter centered at (ox+5..ox+9, oy+4..oy+10) + drop shadow
    rows = LETTER_5X7[letter]
    for ry, row_str in enumerate(rows):
        for rx, ch in enumerate(row_str):
            if ch == "1":
                set_px(g, ox + 6 + rx, oy + 5 + ry, border_lo)  # Shadow
    for ry, row_str in enumerate(rows):
        for rx, ch in enumerate(row_str):
            if ch == "1":
                set_px(g, ox + 5 + rx, oy + 4 + ry, 0x4 if ry <= 2 else glyph_col)


def make_tile6_subtiles():
    g = new_grid(32, 32)
    # 1. Top-Left (0..15, 0..15): Starburst Muzzle Flash
    cx, cy = 7.5, 7.5
    for y in range(16):
        for x in range(16):
            dx = abs(x - cx)
            dy = abs(y - cy)
            d = math.hypot(dx, dy)
            if (dx <= 1.2 and dy <= 6.8) or (dy <= 1.2 and dx <= 6.8) or (abs(dx - dy) <= 0.9 and d <= 5.2):
                set_px(g, x, y, 0x4 if d <= 3.2 else 0x5)
            elif d <= 4.2:
                set_px(g, x, y, 0x5 if d <= 2.8 else 0x6)

    # 2. Top-Right (16..31, 0..15): Item [P] Power-Up (Gold/Orange)
    draw_item_subtile(g, 16, 0, "P", 0xB, 0xA, 0xB)
    # 3. Bottom-Left (0..15, 16..31): Item [S] Shield (Teal-Mint/Cyan)
    draw_item_subtile(g, 0, 16, "S", 0xC, 0x5, 0xC)
    # 4. Bottom-Right (16..31, 16..31): Item [R] Rage/Laser (Cyan/Blue)
    draw_item_subtile(g, 16, 16, "R", 0x5, 0x6, 0x5)
    return g


# =============================================================================
# 7. TILES 7..10: 4-STAGE EXPLOSION (32x32)
# =============================================================================
def make_explosion_tile(stage):
    g = new_grid(32, 32)
    cx, cy = 15.5, 15.5
    for y in range(32):
        for x in range(32):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            angle = math.atan2(dy, dx)
            ray = 2.2 * math.cos(8 * angle)
            eff_d = d + ray

            if stage == 0:
                # Anamorphic core flash + white-gold starburst
                if abs(dy) <= 1.6 and abs(dx) <= 14.5:
                    set_px(g, x, y, 0x4 if abs(dx) <= 10 else 0x5)
                elif eff_d <= 9.5:
                    set_px(g, x, y, 0x4)
                elif eff_d <= 12.5:
                    set_px(g, x, y, 0xB)
                elif eff_d <= 14.2:
                    set_px(g, x, y, 0xA)
            elif stage == 1:
                # Expanding multi-ring plasma fireball
                if eff_d <= 6.5:
                    set_px(g, x, y, 0x4)
                elif eff_d <= 10.5:
                    set_px(g, x, y, 0xB)
                elif eff_d <= 13.8:
                    set_px(g, x, y, 0xA)
                elif eff_d <= 15.5:
                    set_px(g, x, y, 0x9)
            elif stage == 2:
                # Shockwave ring + inner smoke + flying sparks
                if 10.5 <= eff_d <= 13.5:
                    set_px(g, x, y, 0xB if eff_d < 12.0 else 0xA)
                elif 13.5 < eff_d <= 15.5:
                    set_px(g, x, y, 0x9)
                elif 4.5 <= d <= 8.0 and (x + y) % 2 == 0:
                    set_px(g, x, y, 0x9 if d < 6.2 else 0x2)
                elif d < 3.0:
                    set_px(g, x, y, 0xA)
            else:
                # Dissolving smoke puffs & glowing embers
                for sx, sy, sr, sc in [
                    (8, 7, 3.2, 0x2), (22, 8, 3.5, 0x3), (12, 13, 3.8, 0x2),
                    (23, 18, 3.6, 0x3), (8, 21, 3.2, 0x2), (18, 24, 3.5, 0x2),
                ]:
                    sd = math.hypot(x - sx, y - sy)
                    if sd <= sr:
                        set_px(g, x, y, 0x3 if sd <= sr * 0.5 else sc)
                if (x, y) in [(5, 11), (26, 5), (27, 15), (6, 26), (15, 4), (21, 28), (11, 19), (24, 11)]:
                    set_px(g, x, y, 0xB if (x + y) % 2 == 0 else 0x9)
    return g


# =============================================================================
# 8. TILE 11: OVERDRIVE LASER EMITTER SHOCKWAVE RING (32x32)
# =============================================================================
def make_laser_shockwave():
    g = new_grid(32, 32)
    cx = 15.5
    for y in range(32):
        for x in range(32):
            dx = abs(x - cx)
            if y < 26:
                if dx <= 2.5:
                    set_px(g, x, y, 0x4)
                elif dx <= 5.5:
                    set_px(g, x, y, 0x5)
                elif dx <= 8.0:
                    set_px(g, x, y, 0x6)
            # Expanding shockwave vortex in lower half (y = 16..31)
            if y >= 16:
                ell_d = math.hypot((x - cx) / 1.35, (y - 23.5) / 0.75)
                if 7.0 <= ell_d <= 10.5:
                    set_px(g, x, y, 0x4 if ell_d < 8.2 else (0x5 if (x + y) % 2 == 0 else 0x8))
    return g


# =============================================================================
# 9. NATIVE 64x64 GIANT CRATERED & MAGMA ASTEROID (Tiles 12..15)
# =============================================================================
def make_asteroid_64x64():
    g = new_grid(64, 64)
    cx, cy = 31.5, 31.5
    craters = [
        (22, 20, 7.5),
        (40, 22, 6.0),
        (26, 39, 8.5),
        (43, 38, 5.5),
        (17, 33, 4.5),
        (34, 15, 4.0),
        (35, 48, 4.8),
    ]
    for y in range(64):
        for x in range(64):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            # Organic rocky silhouette using multi-harmonic radial modulation
            rad = (
                27.5
                + 2.2 * math.cos(3 * ang + 0.5)
                + 1.6 * math.sin(5 * ang - 0.8)
                + 1.1 * math.cos(7 * ang + 1.2)
                + 0.7 * math.sin(11 * ang)
            )
            if d <= rad:
                # Directional sunlight from Top-Left (-1, -1)
                light = (-dx * 0.7 - dy * 0.7) / 28.0
                # Check if inside any impact crater
                in_crater = False
                crater_col = 0x2
                for crx, cry, crr in craters:
                    cdx = x - crx
                    cdy = y - cry
                    cd = math.hypot(cdx, cdy)
                    if cd <= crr:
                        in_crater = True
                        # Crater inner shadow on top-left, lit rim on bottom-right
                        if cd >= crr - 1.3:
                            crater_col = 0x3 if (cdx + cdy > 0) else 0x1
                        elif cd <= 2.0 and (crx, cry) in [(22, 20), (26, 39)]:
                            # Glowing magma core inside deep craters!
                            crater_col = 0xB if cd < 1.1 else 0x9
                        else:
                            crater_col = 0x1 if (cdx + cdy < 0) else 0x2
                        break

                # Glowing magma fissure veins across the rock
                fissure1 = abs((x - 24) * 0.65 + (y - 28) * 0.75) < 1.0 and 16 <= x <= 42 and 18 <= y <= 44
                fissure2 = abs((x - 36) * 0.8 - (y - 30) * 0.6) < 0.95 and 26 <= x <= 46 and 20 <= y <= 42

                if d >= rad - 1.4:
                    # Outer crisp outline
                    set_px(g, x, y, 0x4 if light > 0.35 else (0x3 if light > -0.1 else 0x2))
                elif in_crater:
                    set_px(g, x, y, crater_col)
                elif fissure1 or fissure2:
                    set_px(g, x, y, 0xA if (x + y) % 2 == 0 else 0x9)
                else:
                    # Dithered 3D rocky shading
                    bayer = ((x & 1) << 1) ^ (y & 1)
                    if light > 0.42:
                        set_px(g, x, y, 0x4 if bayer == 0 else 0x3)
                    elif light > 0.02:
                        set_px(g, x, y, 0x3 if bayer < 3 else 0x2)
                    elif light > -0.35:
                        set_px(g, x, y, 0x2 if bayer < 3 else 0x1)
                    else:
                        set_px(g, x, y, 0x1 if bayer > 0 else 0x2)
    return g


# =============================================================================
# 10. NATIVE 64x64 DREADNOUGHT MOTHERSHIP BOSS (Tiles 24..27 = F0, 28..31 = F1)
# =============================================================================
def make_boss_64x64(frame=0):
    g = new_grid(64, 64)
    claw_shift = 2 if frame == 1 else 0
    core_pulse = 1 if frame == 1 else 0

    for y in range(2, 62):
        for dx in range(32):
            # 1. Upper Command Horns & Armored Crest (y = 2..13)
            if 2 <= y <= 13:
                # Outer dreadnought horns
                horn_min = 12 + (13 - y) // 2
                horn_max = 17 + (13 - y) // 2
                if horn_min <= dx <= horn_max:
                    set_sym(g, y, dx, 0xB if dx == horn_min else (0x8 if dx < horn_max - 1 else 0x7), cx=32)
                # Central command spire
                if y >= 5 and dx <= (4 + (y - 5) // 2):
                    set_sym(g, y, dx, 0x4 if (dx <= 1 and y <= 9) else (0x8 if dx <= 3 else 0x7), cx=32)

            # 2. Main Dreadnought Hull, Glowing Eyes & Wide Wing Pauldrons (y = 14..37)
            elif 14 <= y <= 37:
                wing_span = min(30, 18 + (y - 14) if y <= 26 else 30 - (y - 26) // 2)
                # Twin glowing command eyes at y = 17..22, dx = 5..9
                if 17 <= y <= 22 and 5 <= dx <= 9:
                    if 18 <= y <= 21 and 6 <= dx <= 8:
                        set_sym(g, y, dx, 0x4 if dx == 7 else 0x5, cx=32)
                    else:
                        set_sym(g, y, dx, 0x6, cx=32)
                # Central Anti-Matter Reactor Core at y = 24..35, dx = 0..6
                elif 24 <= y <= 35 and dx <= 6:
                    cd = math.hypot(dx, y - 29.5)
                    if cd <= (3.2 + core_pulse * 0.8):
                        set_sym(g, y, dx, 0x4, cx=32)
                    elif cd <= (5.2 + core_pulse * 0.6):
                        set_sym(g, y, dx, 0x5 if frame == 1 else 0xB, cx=32)
                    elif cd <= 6.8:
                        set_sym(g, y, dx, 0x9 if frame == 1 else 0x8, cx=32)
                    else:
                        set_sym(g, y, dx, 0x2, cx=32)
                elif dx <= wing_span:
                    # Outer golden/crimson wing armor trim
                    if dx >= wing_span - 2:
                        set_sym(g, y, dx, 0xB if y % 2 == 0 else 0x8, cx=32)
                    # Wing-mounted plasma vents & energy ribs
                    elif dx in (14, 15, 21, 22) and 19 <= y <= 33:
                        if y % 3 == frame:
                            set_sym(g, y, dx, 0x5 if dx < 18 else 0x8, cx=32)
                        else:
                            set_sym(g, y, dx, 0x6 if dx < 18 else 0x7, cx=32)
                    # Metallic armor panels
                    elif dx <= 11:
                        set_sym(g, y, dx, 0x8 if (y + dx) % 4 != 0 else 0x7, cx=32)
                    else:
                        set_sym(g, y, dx, 0x3 if (y < 24 and (dx + y) % 2 == 0) else 0x2, cx=32)

            # 3. Lower Weapon Bay, 4 Wing Turrets & Central Death-Ray Cannon (y = 38..60)
            elif 38 <= y <= 60:
                # Central Mega Death-Ray Emitter Barrel (dx <= 5, y = 38..56)
                if y <= 56 and dx <= 5:
                    if y >= 50:
                        # Glowing red/orange/white cannon muzzle
                        set_sym(g, y, dx, 0x4 if (dx <= 1 and frame == 1) else (0x9 if dx <= 3 else 0xA), cx=32)
                    elif dx <= 2:
                        set_sym(g, y, dx, 0x9 if y % 2 == frame else 0xB, cx=32)
                    else:
                        set_sym(g, y, dx, 0x3 if dx == 3 else 0x2, cx=32)
                # Articulated Mechanical Pincer Claws (y = 38..59)
                claw_center = 10 + (y - 38) // 3 + claw_shift - (max(0, y - 50) // 2)
                if abs(dx - claw_center) <= 2 and y <= 59:
                    if y >= 54:
                        set_sym(g, y, dx, 0x4 if abs(dx - claw_center) == 0 else 0xB, cx=32)
                    else:
                        set_sym(g, y, dx, 0x8 if abs(dx - claw_center) <= 1 else 0x7, cx=32)
                # Outer Wing Quad-Turret Barrels (dx in 20..24, y = 38..50)
                if y <= 50 and 19 <= dx <= 24:
                    if y >= 47 and 20 <= dx <= 23:
                        set_sym(g, y, dx, 0x5 if frame == 1 else 0xA, cx=32)
                    elif 20 <= dx <= 23:
                        set_sym(g, y, dx, 0x3 if dx in (20, 21) else 0x2, cx=32)
    return g


def split_64x64_to_4_tiles(g64):
    """Split a 64x64 grid into 4 32x32 tiles in order: TL (0,0), TR (0,1), BL (1,0), BR (1,1)."""
    tiles = []
    for qy in (0, 32):
        for qx in (0, 32):
            t = new_grid(32, 32)
            for y in range(32):
                for x in range(32):
                    t[y][x] = g64[qy + y][qx + x]
            tiles.append(t)
    return tiles


def main():
    tiles = [new_grid(32, 32) for _ in range(32)]

    # Populate all 32 tiles
    tiles[0] = make_player_ship(bank=0)
    tiles[1] = make_elite_alien(frame=0)
    tiles[2] = make_escort_alien(frame=0)
    tiles[3] = make_drone_alien(frame=0)
    tiles[4] = make_shield_ring()

    # Tile 5: 32x32 scaled-down preview of asteroid for legacy fallback
    ast64 = make_asteroid_64x64()
    for y in range(32):
        for x in range(32):
            tiles[5][y][x] = ast64[y * 2][x * 2]

    tiles[6] = make_tile6_subtiles()
    tiles[7] = make_explosion_tile(0)
    tiles[8] = make_explosion_tile(1)
    tiles[9] = make_explosion_tile(2)
    tiles[10] = make_explosion_tile(3)
    tiles[11] = make_laser_shockwave()

    # Tiles 12..15: Native 64x64 Giant Cratered Asteroid
    ast_quads = split_64x64_to_4_tiles(ast64)
    for i in range(4):
        tiles[12 + i] = ast_quads[i]

    # Tile 16: Player Ship Bank Left, Tiles 17..19: Alien Frame 1, Tile 20: Player Ship Bank Right
    tiles[16] = make_player_ship(bank=-1)
    tiles[17] = make_elite_alien(frame=1)
    tiles[18] = make_escort_alien(frame=1)
    tiles[19] = make_drone_alien(frame=1)
    tiles[20] = make_player_ship(bank=1)

    # Tiles 21..23: Alien Frame 2 (Smooth 4-frame animation: Frame 0 -> Frame 1 -> Frame 2 -> Frame 1)
    tiles[21] = make_elite_alien(frame=2)
    tiles[22] = make_escort_alien(frame=2)
    tiles[23] = make_drone_alien(frame=2)

    # Tiles 24..27: Native 64x64 Mothership Boss Frame 0
    boss_f0_quads = split_64x64_to_4_tiles(make_boss_64x64(frame=0))
    for i in range(4):
        tiles[24 + i] = boss_f0_quads[i]

    # Tiles 28..31: Native 64x64 Mothership Boss Frame 1
    boss_f1_quads = split_64x64_to_4_tiles(make_boss_64x64(frame=1))
    for i in range(4):
        tiles[28 + i] = boss_f1_quads[i]

    # Verify tb_shooter assertions!
    assert tiles[0][0][16] == 0x4, "Tile 0 rom[16] must be 4'h4 for tb_shooter!"
    assert tiles[1][8][16] != 0x0, "Tile 1 rom[1024 + 8*32 + 16] must be non-zero for tb_shooter!"

    # Write 32,768 words to all .mem locations
    mem_paths = [
        ROOT / "rtl" / "game" / "sprites_32x32.mem",
        ROOT / "sprites_32x32.mem",
        ROOT / "galaxian_steredenn_fpga_assets" / "sprites_32x32.mem",
    ]
    lines = []
    for tid in range(32):
        for y in range(32):
            for x in range(32):
                lines.append(f"{tiles[tid][y][x]:01X}\n")

    for mp in mem_paths:
        mp.write_text("".join(lines), encoding="ascii")
        print(f"[OK] Wrote {len(lines)} 4-bit pixels (32 tiles) to {mp}")

    # Also generate updated preview image in galaxian_steredenn_fpga_assets/spritesheet_vfx_preview.png
    preview = Image.new("RGB", (680, 560), (11, 13, 24))
    draw = ImageDraw.Draw(preview)
    draw.text((20, 14), "GALAXIAN x STEREDENN FPGA 32-TILE BRAM BANK (32x32 & NATIVE 64x64)", fill=(51, 238, 255))

    def paste_tile(img_grid, px, py, scale=3):
        h = len(img_grid)
        w = len(img_grid[0])
        for y in range(h):
            for x in range(w):
                idx = img_grid[y][x]
                col = PALETTE_RGB[idx] if idx != 0 else (20, 22, 38)
                for sy in range(scale):
                    for sx in range(scale):
                        preview.putpixel((px + x * scale + sx, py + y * scale + sy), col)
        draw.rectangle([px - 1, py - 1, px + w * scale, py + h * scale], outline=(90, 105, 135))

    # Row 1: Ship Straight, Bank L, Bank R, Shield, Items
    showcase = [
        (tiles[0], 20, 48, "[00] Ship Straight"),
        (tiles[16], 150, 48, "[16] Ship Bank L"),
        (tiles[20], 280, 48, "[20] Ship Bank R"),
        (tiles[4], 410, 48, "[04] Hex Shield"),
        (tiles[6], 540, 48, "[06] Flash & P/S/R"),
        (tiles[1], 20, 185, "[01] Elite F0"),
        (tiles[17], 150, 185, "[17] Elite F1"),
        (tiles[2], 280, 185, "[02] Escort F0"),
        (tiles[18], 410, 185, "[18] Escort F1"),
        (tiles[3], 540, 185, "[03/19] Drone F0/1"),
        (tiles[7], 20, 322, "[07] Exp Stage 1"),
        (tiles[8], 150, 322, "[08] Exp Stage 2"),
        (tiles[9], 280, 322, "[09] Exp Stage 3"),
    ]
    for grid, x0, y0, label in showcase:
        paste_tile(grid, x0, y0, scale=3)
        draw.text((x0, y0 + 100), label, fill=(255, 230, 102))

    # Paste Native 64x64 Asteroid & Native 64x64 Boss at scale=2 (128x128px)
    paste_tile(ast64, 405, 322, scale=2)
    draw.text((405, 454), "[12..15] 64x64 Asteroid", fill=(68, 255, 204))
    paste_tile(make_boss_64x64(frame=1), 542, 322, scale=2)
    draw.text((542, 454), "[24..31] 64x64 Boss", fill=(255, 85, 170))

    out_prev = ROOT / "galaxian_steredenn_fpga_assets" / "spritesheet_vfx_preview.png"
    preview.save(out_prev)
    print(f"[OK] Saved sprite bank showcase to {out_prev}")


if __name__ == "__main__":
    main()
