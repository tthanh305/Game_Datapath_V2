"""Generate high-resolution visual preview frame showing the complete Steredenn VFX pipeline."""
import math
from pathlib import Path
from PIL import Image, ImageDraw

def render_preview():
    W, H = 1280, 720
    im = Image.new("RGBA", (W, H), (6, 5, 14, 255))
    draw = ImageDraw.Draw(im)

    # 1. Nebulae & Starfield
    for y in range(64, H, 4):
        for x in range(0, W, 4):
            # Nebulae noise approximation
            h = (x * 7 + y * 13) % 257
            if h > 248:
                draw.rectangle([x, y, x+3, y+3], fill=(25, 15, 45, 160))
            elif h > 240:
                draw.rectangle([x, y, x+1, y+1], fill=(40, 60, 110, 180))

    # Parallax Stars
    import random
    random.seed(42)
    for _ in range(120):
        sx = random.randint(0, W-1)
        sy = random.randint(64, H-1)
        color = random.choice([(255, 255, 255), (100, 220, 255), (255, 120, 120), (255, 240, 100), (80, 120, 255)])
        draw.point((sx, sy), fill=color)

    # 2. Asteroid Field (Rocky debris with chunky shading)
    # Asteroid 1 (28x28)
    a1_x, a1_y = 260, 220
    for dy in range(28):
        for dx in range(28):
            cx = dx - 14
            cy = dy - 14
            if cx*cx + cy*cy <= 169:
                if (cx-3)**2 + (cy+2)**2 <= 9: # Crater
                    c = (34, 25, 21)
                elif cx + cy < -5: # Highlight
                    c = (142, 128, 116)
                elif cx + cy > 5: # Shadow
                    c = (48, 39, 34)
                else:
                    c = (86, 74, 64)
                draw.point((a1_x + dx, a1_y + dy), fill=c)

    # Asteroid 2 (20x20)
    a2_x, a2_y = 920, 480
    for dy in range(20):
        for dx in range(20):
            cx = dx - 10
            cy = dy - 10
            if cx*cx + cy*cy <= 81:
                if (cx+2)**2 + (cy-2)**2 <= 4: # Crater
                    c = (29, 22, 19)
                elif cx + cy < -3: # Highlight
                    c = (124, 114, 104)
                elif cx + cy > 3: # Shadow
                    c = (40, 32, 28)
                else:
                    c = (74, 64, 56)
                draw.point((a2_x + dx, a2_y + dy), fill=c)

    # 3. Enemy Fleet (Boss, Escort, Drone)
    sp_dir = Path("assets/sprites")
    st_dir = Path("assets/sprites/steredenn")
    drone_img = Image.open(sp_dir / "drone_f0.png").convert("RGBA")
    escort_img = Image.open(sp_dir / "escort_f0.png").convert("RGBA")
    boss_img = Image.open(sp_dir / "boss_f0.png").convert("RGBA")

    # Swarm formation (rows: Boss at y=100, Escort at y=160, Drone at y=220, 280)
    for col_idx, cx in enumerate([360, 520, 680, 840]):
        im.paste(boss_img, (cx, 100), boss_img)
        im.paste(escort_img, (cx, 160), escort_img)
        im.paste(drone_img, (cx, 220), drone_img)
        if col_idx != 2: # column 2 is exploding!
            im.paste(drone_img, (cx, 280), drone_img)

    # Ghost Trail behind diving Escort
    ghost_img = escort_img.copy()
    ghost_data = []
    for pixel in ghost_img.getdata():
        if pixel[3] > 0:
            ghost_data.append((42, 16, 64, 180))
        else:
            ghost_data.append((0, 0, 0, 0))
    ghost_img.putdata(ghost_data)
    im.paste(ghost_img, (480, 380), ghost_img)
    im.paste(escort_img, (495, 420), escort_img)

    # 4. 16-Frame Chunky Smoke Explosion + Anamorphic Lens Flare + Hit Sparks
    exp_f4 = Image.open(st_dir / "steredenn_exp_f4.png").convert("RGBA")
    exp_x, exp_y = 680 - 16, 280 - 16
    im.paste(exp_f4, (exp_x, exp_y), exp_f4)

    # Anamorphic Lens Flare (horizontal beam)
    flare_y = 280 + 14
    draw.rectangle([0, flare_y, W, flare_y + 4], fill=(160, 255, 255, 200))
    draw.rectangle([exp_x - 40, flare_y - 2, exp_x + 100, flare_y + 6], fill=(220, 255, 255, 230))

    # Hit Sparks
    spark_img = Image.open(st_dir / "hit_spark_f1.png").convert("RGBA")
    im.paste(spark_img, (680 + 8, 280 + 8), spark_img)

    # Hit Flash: The boss next to it got hit and turns pure white!
    hit_boss = boss_img.copy()
    hit_data = [(255, 255, 255, p[3]) if p[3] > 0 else (0,0,0,0) for p in hit_boss.getdata()]
    hit_boss.putdata(hit_data)
    im.paste(hit_boss, (680, 100), hit_boss)

    # 5. Motion Blur Lasers
    for lx in [600 + 4, 600 + 20]:
        for y_offset in range(24):
            color = (255, 255, 255) if y_offset < 6 else ((0, 255, 255) if y_offset < 18 else (0, 102, 204))
            draw.rectangle([lx, 420 + y_offset, lx + 7, 420 + y_offset], fill=color)

    # 6. Player Ship (Banking Roll Frame 1) + Modular Thruster Flame + Muzzle Flash
    ship_x, ship_y = 600, 580
    bank_f1 = Image.open(st_dir / "ship_bank_f1.png").convert("RGBA")
    thrust_f2 = Image.open(st_dir / "thruster_f2.png").convert("RGBA")
    im.paste(bank_f1, (ship_x, ship_y), bank_f1)
    im.paste(thrust_f2, (ship_x + 9, ship_y + 24), thrust_f2)

    # Muzzle Flash at gun barrels
    draw.polygon([(ship_x + 6, ship_y - 6), (ship_x + 9, ship_y - 3), (ship_x + 6, ship_y), (ship_x + 3, ship_y - 3)], fill=(255, 255, 255))
    draw.polygon([(ship_x + 22, ship_y - 6), (ship_x + 25, ship_y - 3), (ship_x + 22, ship_y), (ship_x + 19, ship_y - 3)], fill=(255, 255, 255))

    # 7. Top HUD (Score, High Score, Wave, Lives)
    draw.rectangle([0, 0, W, 64], fill=(0, 0, 0, 240))
    # HUD text emulation
    draw.text((80, 20), "1UP  012480", fill=(255, 50, 50))
    draw.text((580, 20), "HIGH SCORE  050000", fill=(0, 255, 255))
    draw.text((1050, 20), "STAGE 03", fill=(255, 255, 50))

    # Save to artifacts directory
    art_path = Path(r"C:\Users\thanh\.gemini\antigravity\brain\58b47c13-6381-4da7-810e-6c0c0feae7de\steredenn_vfx_showcase.png")
    im.save(art_path)
    print(f"Saved: {art_path}")

if __name__ == "__main__":
    render_preview()
