"""Generate an animated GIF showing real-time Steredenn gameplay action with Screen Shake and VFX."""
import math
from pathlib import Path
from PIL import Image, ImageDraw
import random

def generate_gif():
    W, H = 640, 360 # scaled virtual canvas for smooth web preview
    frames = []

    sp_dir = Path("assets/sprites")
    st_dir = Path("assets/sprites/steredenn")

    drone_img = Image.open(sp_dir / "drone_f0.png").convert("RGBA").resize((24, 24), Image.Resampling.NEAREST)
    escort_img = Image.open(sp_dir / "escort_f0.png").convert("RGBA").resize((24, 24), Image.Resampling.NEAREST)
    boss_img = Image.open(sp_dir / "boss_f0.png").convert("RGBA").resize((24, 24), Image.Resampling.NEAREST)

    ship_banks = [Image.open(st_dir / f"ship_bank_f{i}.png").convert("RGBA").resize((28, 28), Image.Resampling.NEAREST) for i in range(5)]
    thrusters = [Image.open(st_dir / f"thruster_f{i}.png").convert("RGBA").resize((14, 14), Image.Resampling.NEAREST) for i in range(4)]
    sparks = [Image.open(st_dir / f"hit_spark_f{i}.png").convert("RGBA").resize((16, 16), Image.Resampling.NEAREST) for i in range(3)]
    exps = [Image.open(st_dir / f"steredenn_exp_f{i}.png").convert("RGBA").resize((48, 48), Image.Resampling.NEAREST) for i in range(16)]

    shake_sequence = [(-3, 2), (2, -2), (-2, 1), (1, -1), (-1, 1), (1, 0), (0, 0)]

    for f in range(24): # 24 frames of high-energy combat
        im = Image.new("RGBA", (W, H), (8, 6, 16, 255))
        draw = ImageDraw.Draw(im)

        # Shake offset triggers around explosion (frames 6 to 12)
        if 6 <= f <= 12:
            sh_x, sh_y = shake_sequence[f - 6]
        else:
            sh_x, sh_y = 0, 0

        # Background Stars
        random.seed(99 + f)
        for _ in range(50):
            sx = random.randint(0, W-1)
            sy = (random.randint(32, H-1) + f * 2) % H
            draw.point((sx, sy), fill=(180, 200, 255))

        # Asteroid (drifting across screen)
        ast_x = (140 - f * 2) + sh_x
        ast_y = (80 + f * 3) + sh_y
        draw.ellipse([ast_x, ast_y, ast_x + 18, ast_y + 18], fill=(90, 78, 68), outline=(130, 118, 106))
        draw.ellipse([ast_x + 4, ast_y + 5, ast_x + 8, ast_y + 9], fill=(45, 38, 32)) # crater

        # Swarm Fleet
        fleet_x_base = 180 + int(math.sin(f * 0.3) * 15)
        for c_idx, cx in enumerate([fleet_x_base, fleet_x_base + 80, fleet_x_base + 160, fleet_x_base + 240]):
            im.paste(boss_img, (cx + sh_x, 50 + sh_y), boss_img)
            im.paste(escort_img, (cx + sh_x, 80 + sh_y), escort_img)
            im.paste(drone_img, (cx + sh_x, 110 + sh_y), drone_img)
            if not (c_idx == 2 and f >= 6):
                im.paste(drone_img, (cx + sh_x, 140 + sh_y), drone_img)

        # Diving enemy with Ghost trail
        dive_x = 240 + int(math.sin(f * 0.5) * 30) + sh_x
        dive_y = 120 + f * 8 + sh_y
        if dive_y < H - 40:
            # Ghost trail
            draw.rectangle([dive_x - 6, dive_y - 12, dive_x + 18, dive_y + 12], fill=(42, 16, 64, 120))
            im.paste(escort_img, (dive_x, dive_y), escort_img)

        # Player Ship steering & banking (roll left at start, roll right towards end)
        bank_id = 1 if f < 8 else (2 if f < 14 else 3)
        ship_x = 280 + int(math.sin(f * 0.25) * 40) + sh_x
        ship_y = 300 + sh_y

        # Ship + Thruster
        ship_sprite = ship_banks[bank_id]
        thrust_sprite = thrusters[f % 4]
        im.paste(ship_sprite, (ship_x, ship_y), ship_sprite)
        im.paste(thrust_sprite, (ship_x + 7, ship_y + 24), thrust_sprite)

        # Muzzle Flash when shooting (frames 3, 4 and 15, 16)
        if f in [3, 4, 15, 16]:
            draw.rectangle([ship_x + 3, ship_y - 4, ship_x + 7, ship_y], fill=(255, 255, 255))
            draw.rectangle([ship_x + 19, ship_y - 4, ship_x + 23, ship_y], fill=(255, 255, 255))

        # Motion Blur Lasers
        if f >= 3:
            laser_y = 300 - (f - 3) * 22 + sh_y
            if laser_y > 40:
                for lx in [ship_x + 4, ship_x + 20]:
                    draw.rectangle([lx, laser_y, lx + 3, laser_y + 18], fill=(0, 255, 255))
                    draw.rectangle([lx, laser_y, lx + 3, laser_y + 4], fill=(255, 255, 255))

        # Explosion at col 2, drone y=140
        if f >= 6:
            exp_id = min(15, f - 6)
            exp_sprite = exps[exp_id]
            target_x = fleet_x_base + 160 - 12 + sh_x
            target_y = 140 - 12 + sh_y
            im.paste(exp_sprite, (target_x, target_y), exp_sprite)

            # Hit sparks on impact
            if f <= 8:
                im.paste(sparks[f - 6], (target_x + 16, target_y + 16), sparks[f - 6])

            # Anamorphic Lens Flare
            if f in [6, 7]:
                draw.rectangle([0, target_y + 20, W, target_y + 22], fill=(160, 255, 255, 180))

        # Top HUD (Rock solid, NO SHAKE)
        draw.rectangle([0, 0, W, 28], fill=(0, 0, 0, 255))
        draw.text((30, 8), "1UP  012480", fill=(255, 60, 60))
        draw.text((250, 8), "HIGH SCORE  050000", fill=(0, 255, 255))
        draw.text((520, 8), "STAGE 03", fill=(255, 255, 50))

        # Convert to P-mode for compact GIF
        frames.append(im.convert("RGB"))

    out_gif = Path(r"C:\Users\thanh\.gemini\antigravity\brain\58b47c13-6381-4da7-810e-6c0c0feae7de\steredenn_action_showcase.gif")
    frames[0].save(out_gif, save_all=True, append_images=frames[1:], duration=60, loop=0)
    print(f"Saved: {out_gif}")

if __name__ == "__main__":
    generate_gif()
