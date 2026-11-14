#!/usr/bin/env python3
"""
Design High-Definition Pixel-Art Assets for Boss 2:
"Void Carrier Leviathan" (Wave 10 Modular Flagship).
Generates:
  1. Main Flagship Hull (128x64) with paneling, bridge, radiators, hazard stripes
  2. Dual Heavy Railgun Turret (32x32) with dual barrels & optic sensor
  3. Destroyed Turret Wreckage (32x32)
  4. 4-Frame Pulsing Hyper-Matter Core (32x32 x 4)
  5. Hangar Gate Assembly (Open & Closed)
"""

import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

PALETTE_RGBA = {
    0x0: (0, 0, 0, 0),             # TRANSPARENT
    0x1: (0x11, 0x11, 0x22, 255),  # DEEP_SHADOW
    0x2: (0x22, 0x33, 0x48, 255),  # DARK_HULL_ARMOR
    0x3: (0x4A, 0x60, 0x7A, 255),  # STEEL_GREY_PLATING
    0x4: (0xFF, 0xFF, 0xFF, 255),  # PURE_WHITE_HIGHLIGHT
    0x5: (0x33, 0xEE, 0xFF, 255),  # CYAN_GLOW
    0x6: (0x1D, 0x70, 0xE0, 255),  # BLUE_ENERGY
    0x7: (0x99, 0x33, 0xDD, 255),  # PURPLE_SHIELD
    0x8: (0xFF, 0x44, 0x99, 255),  # PINK_CORE
    0x9: (0xFF, 0x2A, 0x2A, 255),  # CRIMSON_WARNING
    0xA: (0xFF, 0x88, 0x11, 255),  # ORANGE_THRUSTER
    0xB: (0xFF, 0xDD, 0x33, 255),  # GOLD_HAZARD
    0xC: (0x33, 0xDD, 0xAA, 255),  # TEAL_MINT
    0xD: (0x18, 0x1C, 0x28, 255),  # INNER_CHASSIS
    0xE: (0x38, 0x48, 0x58, 255),  # SHADOW_PLATING
    0xF: (0x75, 0x88, 0x9E, 255),  # LIGHT_METALLIC
}

def new_grid(w, h):
    return [[0 for _ in range(w)] for _ in range(h)]

def set_p(g, x, y, col):
    if 0 <= x < len(g[0]) and 0 <= y < len(g):
        g[y][x] = col

def grid_to_img(g):
    h = len(g)
    w = len(g[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            val = g[y][x]
            img.putpixel((x, y), PALETTE_RGBA.get(val, (0, 0, 0, 0)))
    return img

def make_white_flash(img):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            if a > 0:
                out.putpixel((x, y), (255, 255, 255, 255))
    return out

# =============================================================================
# 1. MAIN FLAGSHIP HULL (128x64)
# =============================================================================
def generate_carrier_hull():
    W, H = 128, 64
    g = new_grid(W, H)
    cx = W // 2  # 64

    # We mirror x across center axis cx for perfect symmetry!
    for y in range(H):
        for dx in range(64):
            x_l = cx - 1 - dx
            x_r = cx + dx

            # -------------------------------------------------------------
            # A. Outrigger Heavy Wings & Sponsons (dx = 32..63)
            # -------------------------------------------------------------
            if 32 <= dx <= 63:
                # Wing silhouette: swept-forward stealth wedge
                # Top edge sweeps from y=8 at dx=32 to y=18 at dx=60
                wing_top = 8 + int((dx - 32) * 0.38)
                # Bottom edge extends to y=56 at dx=32, tapers up to y=46 at dx=60
                wing_bot = 56 - int((dx - 32) * 0.35)
                # Wingtip fin at dx=60..63
                if dx >= 60:
                    wing_top = 16 - (dx - 60) * 3
                    wing_bot = 48 + (dx - 60) * 3

                if wing_top <= y <= wing_bot:
                    # Outer armor outline
                    if y == wing_top or y == wing_bot or dx in (62, 63):
                        col = 0x1 if y == wing_bot else (0x4 if y == wing_top else 0x3)
                    elif dx in (32, 33):
                        col = 0x1  # Bulkhead seam
                    elif 44 <= dx <= 56 and 22 <= y <= 38:
                        # Heavy cooling radiator grille with glowing slats
                        if y % 3 == 0:
                            col = 0xA if (y // 3) % 2 == 0 else 0x9  # Glowing heat slat
                        else:
                            col = 0x1  # Deep slat shadow
                    elif dx >= 54:
                        # Wingtip secondary armor plate
                        col = 0xF if y == wing_top + 1 else 0x3
                    else:
                        # 3D beveled plate shading
                        bayer = ((dx & 1) << 1) ^ (y & 1)
                        if y < wing_top + 4:
                            col = 0x4 if bayer == 0 else 0xF
                        elif y > wing_bot - 4:
                            col = 0x1 if bayer == 0 else 0x2
                        else:
                            col = 0x3 if bayer < 3 else 0xE
                    set_p(g, x_l, y, col)
                    set_p(g, x_r, y, col)

                # Turret Mount Barbette Ring at (dx=48, y=20)
                tdx = dx - 48
                tdy = y - 20
                if tdx*tdx + tdy*tdy <= 196:  # Radius 14 ring
                    d_barb = math.hypot(tdx, tdy)
                    if 12.0 <= d_barb <= 14.0:
                        col = 0x4 if tdy < 0 else 0x1  # Barbette rim highlight
                    elif 10.0 <= d_barb < 12.0:
                        col = 0x3
                    else:
                        col = 0xD  # Inner turret well
                    set_p(g, x_l, y, col)
                    set_p(g, x_r, y, col)

            # -------------------------------------------------------------
            # B. Center Armored Citadel & Bridge (dx = 0..31)
            # -------------------------------------------------------------
            elif dx < 32:
                # Center hull profile:
                # Command bridge peak at y=2..12, dx=0..14
                # Main citadel at y=6..58, dx=0..31
                in_bridge = (2 <= y <= 14) and (dx <= 14 - (y - 2) // 3)
                in_citadel = (8 <= y <= 56)
                # Rear engine nacelles at bottom y=52..62, dx=14..28
                in_engine = (52 <= y <= 62) and (14 <= dx <= 28)

                if in_bridge or in_citadel or in_engine:
                    # Outer perimeter outline
                    if in_bridge and (y == 2 or dx == 14 - (y - 2) // 3):
                        col = 0x4
                    elif in_citadel and (y == 8 or dx == 31 or y == 56):
                        col = 0x4 if y == 8 else (0x1 if y == 56 else 0x3)
                    elif in_engine and (y >= 58 or dx in (14, 28)):
                        col = 0x1
                    # Bridge Visor Glass (y=6..9, dx=2..10)
                    elif 6 <= y <= 9 and 2 <= dx <= 10:
                        col = 0x5 if (y == 7 and 3 <= dx <= 9) else 0x6
                    # Hangar Catapult Bay Well (dx <= 22, y=20..50)
                    elif 20 <= y <= 50 and dx <= 22:
                        # Bay walls and perimeter warning chevrons
                        if dx in (21, 22):
                            # Yellow/Black hazard chevron border
                            chevron = (dx + y) % 6 < 3
                            col = 0xB if chevron else 0x1
                        elif y in (20, 21):
                            col = 0x1
                        elif y in (49, 50):
                            col = 0x3
                        else:
                            # Inner dark hangar floor with glowing landing lights
                            if dx in (6, 16) and (y % 6 == 0):
                                col = 0x5  # Cyan runway LED
                            elif dx in (10, 12) and y >= 36:
                                col = 0xA  # Catapult rail groove
                            else:
                                col = 0xD  # Dark interior shadow
                    # Engine Exhaust Nozzles
                    elif 56 <= y <= 62 and 16 <= dx <= 26:
                        if y >= 60:
                            col = 0xA if dx in (20, 21, 22) else 0x9
                        else:
                            col = 0x2
                    else:
                        # Armored deck plates
                        bayer = ((dx & 1) << 1) ^ (y & 1)
                        if y < 16:
                            col = 0xF if bayer == 0 else 0x3
                        elif y > 46:
                            col = 0x2 if bayer == 0 else 0x1
                        else:
                            col = 0x3 if bayer < 3 else 0x2
                    set_p(g, x_l, y, col)
                    set_p(g, x_r, y, col)

    return grid_to_img(g)

# =============================================================================
# 2. DUAL HEAVY RAILGUN TURRET (32x32)
# =============================================================================
def generate_turret_sprite(recoil=0):
    W, H = 32, 32
    g = new_grid(W, H)
    cx, cy = 16, 16

    # 1. Circular armored barbette base (radius 10)
    for y in range(H):
        for x in range(W):
            dx = x - cx
            dy = y - cy
            d2 = dx*dx + dy*dy
            if d2 <= 100:  # Radius 10
                d = math.hypot(dx, dy)
                if d >= 8.5:
                    # Rim
                    set_p(g, x, y, 0x4 if dy < -2 else (0x1 if dy > 2 else 0x3))
                elif d >= 6.5:
                    # Rivet ring
                    set_p(g, x, y, 0x2)
                else:
                    set_p(g, x, y, 0x3)

    # 2. Dual Heavy Railgun Barrels pointing UPWARDS (y=0..16)
    # Gun barrels are at x = cx - 5 and x = cx + 5 (width 3, length 14 - recoil)
    bar_y_start = max(1, 2 + recoil)
    bar_y_end = 16
    for bx in (cx - 5, cx + 3):
        for by in range(bar_y_start, bar_y_end):
            for bw in range(3):
                px = bx + bw
                if by == bar_y_start:
                    col = 0x4  # Muzzle highlight
                elif by == bar_y_start + 1:
                    col = 0x5  # Plasma muzzle coil
                elif bw == 0:
                    col = 0xF  # Left highlight
                elif bw == 2:
                    col = 0x1  # Right shadow
                else:
                    col = 0x3  # Core steel
                set_p(g, px, by, col)
            # Muzzle brake side vents
            if by in (bar_y_start + 3, bar_y_start + 6):
                set_p(g, bx - 1, by, 0x5)
                set_p(g, bx + 3, by, 0x5)

    # 3. Central Mantlet & Targeting Sensor (x=13..18, y=13..19)
    for y in range(13, 20):
        for x in range(13, 19):
            if y in (15, 16) and x in (15, 16):
                set_p(g, x, y, 0x9)  # Ruby target finder lens
            elif y == 15 and x in (14, 17):
                set_p(g, x, y, 0x4)  # Lens glint
            else:
                set_p(g, x, y, 0x2)

    return grid_to_img(g)

# =============================================================================
# 3. DESTROYED TURRET WRECKAGE (32x32)
# =============================================================================
def generate_dead_turret():
    W, H = 32, 32
    g = new_grid(W, H)
    cx, cy = 16, 16
    # Scorched jagged metal remnants
    for y in range(H):
        for x in range(W):
            dx = x - cx
            dy = y - cy
            d2 = dx*dx + dy*dy
            if d2 <= 81:
                # Random ragged rim
                hash_v = ((x * 17) ^ (y * 31)) & 7
                if hash_v > 2:
                    set_p(g, x, y, 0x1)  # Charred black
                elif hash_v == 2:
                    set_p(g, x, y, 0x2)  # Dark slag
                elif hash_v == 1:
                    set_p(g, x, y, 0x9 if (x+y)%2==0 else 0xA)  # Glowing hot ember
    # Snapped severed barrel stubs
    set_p(g, cx - 4, 11, 0x2)
    set_p(g, cx - 4, 12, 0x1)
    set_p(g, cx + 4, 13, 0x2)
    set_p(g, cx + 4, 14, 0x1)
    return grid_to_img(g)

# =============================================================================
# 4. 4-FRAME ANIMATED HYPER-MATTER REACTOR CORE (32x32 x 4)
# =============================================================================
def generate_core_frame(frame=0):
    W, H = 32, 32
    g = new_grid(W, H)
    cx, cy = 16, 16
    pulse = frame % 4
    r_core = 7.0 + (pulse if pulse < 2 else (3 - pulse)) * 1.5

    for y in range(H):
        for x in range(W):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            
            # Outer containment magnetic claws (at 0, 90, 180, 270 deg)
            in_claw = False
            for c_ang in (0, math.pi/2, math.pi, 3*math.pi/2):
                if abs(ang - c_ang) < 0.22 and 8.0 <= d <= 13.0:
                    set_p(g, x, y, 0x4 if d >= 12.0 else 0x3)
                    in_claw = True
                    break
            if in_claw:
                continue

            # Multi-layer plasma energy core
            if d <= r_core:
                if d < r_core * 0.35:
                    set_p(g, x, y, 0x4)  # Pure white burning core
                elif d < r_core * 0.65:
                    set_p(g, x, y, 0x5)  # Cyan neon plasma
                elif d < r_core * 0.85:
                    set_p(g, x, y, 0x6)  # Deep blue energy
                else:
                    set_p(g, x, y, 0x7 if pulse % 2 == 1 else 0x8)  # Violet/Pink perimeter flare
            elif d <= r_core + 2.0:
                # Corona sparkles
                if ((x * 13 + y * 7 + pulse * 5) % 9) == 0:
                    set_p(g, x, y, 0x5)
    return grid_to_img(g)

# =============================================================================
# 5. HANGAR BLAST GATE (OPEN & CLOSED, 44x24)
# =============================================================================
def generate_hangar_door(open_state=False):
    W, H = 44, 24
    g = new_grid(W, H)
    for y in range(H):
        for x in range(W):
            # Heavy industrial segmented blast door with diagonal hazard striping
            if open_state:
                # Door retracted to the top/bottom edges
                if y <= 4 or y >= 20:
                    set_p(g, x, y, 0x3 if (x+y)%4 < 2 else 0x1)
                else:
                    set_p(g, x, y, 0x0)
            else:
                # Fully closed armored hatch
                if y in (0, H - 1) or x in (0, W - 1):
                    set_p(g, x, y, 0x1)
                elif y in (1, H - 2) or x in (1, W - 2):
                    set_p(g, x, y, 0x3)
                elif y in (11, 12):
                    set_p(g, x, y, 0x1)  # Center seam where dual doors meet
                elif (x + y) % 8 < 4 and 4 <= y <= 19:
                    set_p(g, x, y, 0xB)  # Warning Yellow stripe
                else:
                    set_p(g, x, y, 0x2)  # Dark armor plate
    return grid_to_img(g)

def main():
    print("Generating High-Definition Pixel-Art for Boss 2...")
    hull = generate_carrier_hull()
    turret = generate_turret_sprite(recoil=0)
    turret_rec = generate_turret_sprite(recoil=2)
    turret_dead = generate_dead_turret()
    core_f0 = generate_core_frame(0)
    core_f1 = generate_core_frame(1)
    core_f2 = generate_core_frame(2)
    core_f3 = generate_core_frame(3)
    door_closed = generate_hangar_door(open_state=False)
    door_open = generate_hangar_door(open_state=True)

    # Save to assets/sprites/extracted_frames
    out_dir = ROOT / "assets" / "sprites" / "extracted_frames"
    out_dir.mkdir(parents=True, exist_ok=True)
    
    hull.save(out_dir / "boss2_leviathan_hull.png")
    turret.save(out_dir / "boss2_turret.png")
    turret_dead.save(out_dir / "boss2_turret_dead.png")
    core_f0.save(out_dir / "boss2_core_f0.png")
    door_closed.save(out_dir / "boss2_door_closed.png")
    door_open.save(out_dir / "boss2_door_open.png")

    # Composite Complete Boss 2 Preview (128x64)
    comp = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    # 1. Main Hull
    comp.paste(hull, (0, 0), hull)
    # 2. Hangar door
    comp.paste(door_closed, (42, 24), door_closed)
    # 3. Core
    comp.paste(core_f0, (48, 16), core_f0)
    # 4. Left Turret
    comp.paste(turret, (32, 4), turret)
    # 5. Right Turret
    comp.paste(turret, (64, 4), turret)

    comp.save(out_dir / "boss2_composite_preview.png")

    # High-res 4x zoom preview
    comp_x4 = comp.resize((128 * 4, 64 * 4), Image.NEAREST)
    comp_x4.save(out_dir / "boss2_composite_preview_x4.png")

    # Also save to Artifact directory
    art_dir = Path(r"C:\Users\thanh\.gemini\antigravity\brain\f6c0c5db-1b1d-474e-89e6-71cfbe17553e")
    comp_x4.save(art_dir / "boss2_composite_preview_x4.png")
    hull.resize((128*4, 64*4), Image.NEAREST).save(art_dir / "boss2_hull_x4.png")
    turret.resize((32*4, 32*4), Image.NEAREST).save(art_dir / "boss2_turret_x4.png")
    core_f0.resize((32*4, 32*4), Image.NEAREST).save(art_dir / "boss2_core_x4.png")

    print("[SUCCESS] Boss 2 Pixel-Art generated successfully!")

if __name__ == "__main__":
    main()
