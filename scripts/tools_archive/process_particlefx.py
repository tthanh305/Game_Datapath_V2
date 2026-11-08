"""
=============================================================================
EXTRACT & PROCESS PARTICLEFX.STUDIO ASSETS FOR FPGA
Trích xuất chuỗi 8 frame từ boss_strip.webp (1280x160):
- Mỗi frame là 160x160 pixel
- Tách màu nền tối thành Transparent
- Resize thành chuẩn 64x64 pixel cho FPGA BRAM
- Cung cấp 4 frame cực đại và kết thúc cho vụ nổ trùm hoành tráng!
=============================================================================
"""

from pathlib import Path
from PIL import Image

FX_DIR = Path("assets/downloaded_fx")
OUT_SPRITES = Path("assets/sprites")

# 1. Đọc boss_strip.webp (1280x160 gồm 8 frame 160x160)
strip_path = FX_DIR / "boss_strip.webp"
strip = Image.open(strip_path).convert("RGBA")

frames = []
for i in range(8):
    box = (i * 160, 0, (i + 1) * 160, 160)
    frame = strip.crop(box)
    
    # Loại bỏ nền tối đen (Chuyển thành Alpha = 0 nếu tối)
    frame_rgba = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    for y in range(160):
        for x in range(160):
            r, g, b, a = frame.getpixel((x, y))
            # Nếu pixel gần đen (r,g,b < 35) -> trong suốt
            if r < 35 and g < 35 and b < 35:
                continue
            else:
                frame_rgba.putpixel((x, y), (r, g, b, 255))
    
    # Resize chuẩn 64x64 cho FPGA
    frame_64 = frame_rgba.resize((64, 64), Image.NEAREST)
    frames.append(frame_64)
    print(f"Extracted Frame {i}: 160x160 -> 64x64")

# Chọn 4 frame tiêu biểu nhất cho VỤ NỔ QUÁI ĐỊCH:
# Frame 1: Tia chớp khởi phát
# Frame 3: Cầu lửa nổ cực đại
# Frame 5: Sóng xung kích bung tỏa
# Frame 7: Mảnh vụn và tàn tro
frames[1].save(OUT_SPRITES / "alien_exp_f0.png")
frames[3].save(OUT_SPRITES / "alien_exp_f1.png")
frames[5].save(OUT_SPRITES / "alien_exp_f2.png")
frames[7].save(OUT_SPRITES / "alien_exp_f3.png")

print("Saved 4 Alien Explosion frames from ParticleFX Studio!")

# 2. Xử lý digital_exp.webp và boss_defeat.webp làm hiệu ứng nổ Tàu Người Chơi
# Đọc boss_poster.webp làm vụ nổ siêu cấp
poster = Image.open(FX_DIR / "boss_poster.webp").convert("RGBA")
p_rgba = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
for y in range(256):
    for x in range(256):
        r, g, b, a = poster.getpixel((x, y))
        if r < 35 and g < 35 and b < 35:
            continue
        p_rgba.putpixel((x, y), (r, g, b, 255))

# Tạo 4 frame cho nổ tàu người chơi từ các thời điểm bùng nổ
f0 = p_rgba.resize((32, 32), Image.NEAREST).resize((64, 64), Image.NEAREST) # Nở nhỏ ban đầu
f1 = p_rgba.resize((64, 64), Image.NEAREST) # Cực đại 64x64
# f2, f3 tạo tan rã
f2 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
f3 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
for y in range(64):
    for x in range(64):
        r, g, b, a = f1.getpixel((x, y))
        if a > 0:
            if (x + y) % 2 == 0: f2.putpixel((x, y), (r, g, b, a))
            if (x * 3 + y * 7) % 5 == 0: f3.putpixel((x, y), (r, g, b, a))

f0.save(OUT_SPRITES / "player_exp_f0.png")
f1.save(OUT_SPRITES / "player_exp_f1.png")
f2.save(OUT_SPRITES / "player_exp_f2.png")
f3.save(OUT_SPRITES / "player_exp_f3.png")

print("Saved 4 Player Explosion frames from ParticleFX Studio!")

