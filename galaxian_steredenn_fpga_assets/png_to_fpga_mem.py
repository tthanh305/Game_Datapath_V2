#!/usr/bin/env python3
"""Convert any 32x32 PNG Sprite Sheet into Verilog .MEM / Xilinx .COE / Quartus .MIF"""
from PIL import Image
import sys

def png_to_mem(png_path, mem_path):
    img = Image.open(png_path).convert("P", palette=Image.ADAPTIVE, colors=16)
    w, h = img.size
    pixels = list(img.getdata())
    with open(mem_path, "w") as f:
        for p in pixels:
            f.write(f"{p & 0xF:01X}\n")
    print(f"Exported {len(pixels)} 4-bit pixels ({w}x{h}) to {mem_path}")

if __name__ == "__main__":
    if len(sys.argv) >= 3:
        png_to_mem(sys.argv[1], sys.argv[2])
