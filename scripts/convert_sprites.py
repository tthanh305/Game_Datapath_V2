"""
=============================================================================
SPRITE CONVERTER CHO FPGA (PNG/BMP -> Vivado .COE / Verilog .HEX)
Game: Galaxian / Space Shooter trên EBAZ4205 (Zynq-7010)
=============================================================================
Yêu cầu thư viện:
    pip install pillow

Cách sử dụng:
    1. Chép ảnh PNG/BMP vào thư mục assets/sprites/
    2. Chạy lệnh:
       python scripts/convert_sprites.py
    3. Script sẽ tự quét toàn bộ ảnh trong assets/sprites/ và sinh ra:
       - File .coe (dùng cho Xilinx Block Memory Generator IP)
       - File .hex (dùng cho Verilog $readmemh)
=============================================================================
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("[-] Thư viện Pillow chưa được cài đặt. Vui lòng chạy: pip install pillow")
    sys.exit(1)

SPRITES_DIR = Path(__file__).resolve().parent.parent / "assets" / "sprites"
OUTPUT_DIR = SPRITES_DIR / "generated"

# Màu được coi là trong suốt (Alpha = 0 hoặc trùng Transparent Key)
TRANSPARENT_KEY = 0x000000  # Màu đen hoặc vùng alpha = 0

def convert_image(img_path: Path):
    print(f"[+] Đang xử lý: {img_path.name}")
    img = Image.open(img_path).convert("RGBA")
    width, height = img.size

    # Kiểm tra kích thước lũy thừa 2
    valid_sizes = [(16, 16), (32, 32), (64, 64), (16, 32), (32, 16), (128, 32), (64, 16)]
    if (width, height) not in valid_sizes:
        print(f"  [!] Cảnh báo: Kích thước {width}x{height} có thể không tối ưu cho Block RAM (nên là 16x16, 32x32, 64x64).")

    pixels_24bit = []
    for y in range(height):
        for x in range(width):
            r, g, b, a = img.getpixel((x, y))
            # Nếu pixel trong suốt (alpha < 128) -> gán mã màu đen (hoặc mã trong suốt)
            if a < 128:
                rgb_val = 0x000000
            else:
                rgb_val = (r << 16) | (g << 8) | b
            pixels_24bit.append(rgb_val)

    stem = img_path.stem
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Xuất file .coe (Xilinx BRAM IP)
    coe_file = OUTPUT_DIR / f"{stem}.coe"
    with open(coe_file, "w", encoding="utf-8") as f:
        f.write("; Sprite COE File for Vivado BRAM\n")
        f.write(f"; Size: {width}x{height}, Total words: {len(pixels_24bit)}\n")
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        hex_strs = [f"{val:06X}" for val in pixels_24bit]
        f.write(",\n".join(hex_strs) + ";\n")

    # 2. Xuất file .hex (Verilog $readmemh)
    hex_file = OUTPUT_DIR / f"{stem}.hex"
    with open(hex_file, "w", encoding="utf-8") as f:
        for val in pixels_24bit:
            f.write(f"{val:06X}\n")

    print(f"  -> Xuất thành công: {coe_file.name} và {hex_file.name} ({len(pixels_24bit)} words)")

def main():
    if not SPRITES_DIR.exists():
        print(f"[-] Không tìm thấy thư mục: {SPRITES_DIR}")
        return

    image_exts = {".png", ".bmp", ".jpg", ".jpeg"}
    images = [p for p in SPRITES_DIR.iterdir() if p.suffix.lower() in image_exts]

    if not images:
        print(f"[*] Chưa có ảnh nào trong: {SPRITES_DIR}")
        print("    Hãy đặt các file ảnh .png (ví dụ: ship.png, boss.png) vào thư mục đó rồi chạy lại.")
        return

    print(f"[*] Tìm thấy {len(images)} ảnh. Bắt đầu chuyển đổi...")
    for img_p in images:
        convert_image(img_p)
    print("\n[V] Hoàn tất! Tất cả file ROM đã sẵn sàng trong: assets/sprites/generated/")

if __name__ == "__main__":
    main()

