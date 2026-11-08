"""
=============================================================================
CYBERPUNK / SCI-FI MECHA SPRITE GENERATOR (STYLE STEREDENN / MODERN SHMUP)
Thiết kế lại 100% đồ họa:
1. SHIP (Interceptor Mecha): Tàu chiến phản lực tương lai góc cạnh, cánh vát tàng hình, buồng lái phát quang, ống xả plasma kép.
2. BOSS (Dreadnought Core): Pháo đài không gian Mecha, lõi năng lượng phản vật chất đập thình thịch, 2 cánh vũ khí hạng nặng.
3. ESCORT (Plasma Stalker): Tàu săn mồi cơ khí đỏ rực, cánh lưỡi dao laze, mắt quét tầm nhiệt đỏ neon.
4. DRONE (Cyber Wasp / Gun-Drone): Drone chiến đấu lục giác cơ động, cánh phát quang điện từ.
5. VỤ NỔ 64x64 ĐỘC LẬP:
   - ALIEN: Vụ nổ siêu tân tinh phản vật chất (Sóng xung kích điện từ EMP lục giác, bão hạt tím / xanh neon).
   - PLAYER: Vụ nổ hạt nhân cơ khí (Lõi plasma trắng, mảnh vỡ thân tàu xé toạc, khói lửa cuồn cuộn).
=============================================================================
"""

import math
from pathlib import Path
from PIL import Image

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sprites"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Bảng màu Cyberpunk / Sci-Fi Neon Palette cực kỳ phong phú
C_TRANS      = (0, 0, 0, 0)
# Tông Kim loại Mecha Tàu & Giáp
C_STEEL_HI   = (220, 235, 255, 255) # Kim loại sáng bóng
C_STEEL_MID  = (130, 150, 180, 255) # Thép xám xanh
C_STEEL_DK   = (40, 50, 70, 255)    # Khung sườn titan đen
C_PANEL_DK   = (20, 25, 38, 255)    # Tấm giáp đen góc cạnh
C_BOLT       = (180, 190, 210, 255) # Đinh tán / khớp nối
# Tông Năng lượng Cyberpunk Neon
C_CYAN_CORE  = (255, 255, 255, 255)
C_CYAN_GLOW  = (0, 240, 255, 255)   # Neon Cyan
C_CYAN_DEEP  = (0, 120, 200, 255)
C_PURP_GLOW  = (220, 40, 255, 255)  # Neon Purple
C_PURP_DEEP  = (110, 10, 160, 255)
C_ORANGE_FIRE= (255, 120, 0, 255)   # Lửa plasma cam
C_YELLOW_CORE= (255, 240, 80, 255)
# Tông Địch (Hostile Alien Mecha)
C_RED_NEON   = (255, 20, 50, 255)   # Đỏ Neon cảnh báo
C_RED_DEEP   = (140, 5, 20, 255)
C_CRIMSON    = (200, 15, 35, 255)
C_LIME_NEON  = (50, 255, 100, 255)  # Lục Neon Cyber
C_LIME_DEEP  = (10, 140, 40, 255)
C_GOLD_ARMOR = (255, 190, 0, 255)   # Giáp vàng Boss
C_GOLD_DEEP  = (170, 110, 0, 255)

def create_canvas(w=32, h=32):
    return Image.new("RGBA", (w, h), C_TRANS)

def set_sym(img, cx, y, dx, color):
    w, h = img.size
    if 0 <= y < h:
        x1 = cx - dx
        x2 = cx + dx - 1 if dx > 0 else cx
        if 0 <= x1 < w: img.putpixel((x1, y), color)
        if 0 <= x2 < w: img.putpixel((x2, y), color)

# =============================================================================
# 1. TÀU CHIẾN TƯƠNG LAI MECHA (INTERCEPTOR SHIP - 32x32)
# =============================================================================
def draw_mecha_ship(frame=0):
    img = create_canvas(32, 32)
    # Mũi tàu tàng hình nhọn vát góc kim loại & Đèn cảm biến Cyan
    set_sym(img, 16, 2, 1, C_CYAN_GLOW)
    set_sym(img, 16, 3, 1, C_STEEL_HI)
    set_sym(img, 16, 4, 1, C_STEEL_HI)
    set_sym(img, 16, 4, 2, C_STEEL_MID)

    # Thân trên & Buồng lái năng lượng Cyan phản quang
    for y in range(5, 9):
        set_sym(img, 16, y, 1, C_CYAN_CORE)
        set_sym(img, 16, y, 2, C_CYAN_GLOW)
        set_sym(img, 16, y, 3, C_STEEL_HI)

    # Giáp thân giữa góc cạnh với khe thoát nhiệt
    for y in range(9, 15):
        set_sym(img, 16, y, 1, C_PANEL_DK)
        set_sym(img, 16, y, 2, C_STEEL_MID)
        set_sym(img, 16, y, 3, C_STEEL_HI)
        set_sym(img, 16, y, 4, C_STEEL_DK)

    # Cánh vát phản lực vươn rộng (Stealth Wings) + Đèn neon ở rãnh cánh
    for y in range(15, 23):
        span = 5 + (y - 14) * 2 # Mở rộng từ dx=5 đến 15
        set_sym(img, 16, y, 1, C_STEEL_DK)
        set_sym(img, 16, y, 2, C_STEEL_MID)
        for dx in range(3, span):
            if dx == span - 1:
                set_sym(img, 16, y, dx, C_STEEL_HI) # Viền cánh sắc bén
            elif dx == span - 2:
                set_sym(img, 16, y, dx, C_CYAN_GLOW) # Rãnh năng lượng Neon
            elif dx == 5:
                set_sym(img, 16, y, dx, C_PANEL_DK)
            else:
                set_sym(img, 16, y, dx, C_STEEL_MID)

    # Nòng Pháo Railgun / Plasma Cannon ở 2 đầu cánh
    for y in range(18, 25):
        set_sym(img, 16, y, 13, C_STEEL_HI)
        set_sym(img, 16, y, 14, C_CYAN_GLOW if (y in [19,20] and frame==1) else C_STEEL_DK)

    # Cụm động cơ phản lực kép ở đuôi (Dual Plasma Thrusters)
    for y in range(23, 27):
        set_sym(img, 16, y, 1, C_PANEL_DK)
        set_sym(img, 16, y, 2, C_CYAN_GLOW if frame==0 else C_CYAN_CORE)
        set_sym(img, 16, y, 3, C_CYAN_GLOW)
        set_sym(img, 16, y, 4, C_STEEL_DK)

    # Ngọn lửa Plasma phụt từ ống xả kép (Thruster Animation)
    if frame == 0:
        # Xung năng lượng Cyan ngắn
        for dx in [2, 3]:
            set_sym(img, 16, 27, dx, C_CYAN_CORE)
            set_sym(img, 16, 28, dx, C_CYAN_GLOW)
            set_sym(img, 16, 29, dx, C_CYAN_DEEP)
    else:
        # Xung bùng nổ cực mạnh (Frame 1)
        for dx in [2, 3]:
            set_sym(img, 16, 27, dx, C_CYAN_CORE)
            set_sym(img, 16, 28, dx, C_CYAN_CORE)
            set_sym(img, 16, 29, dx, C_CYAN_GLOW)
            set_sym(img, 16, 30, dx, C_CYAN_GLOW)
            set_sym(img, 16, 31, dx, C_CYAN_DEEP)
        set_sym(img, 16, 30, 1, C_PURP_GLOW)
        set_sym(img, 16, 30, 4, C_PURP_GLOW)

    return img

# =============================================================================
# 2. PHÁO ĐÀI DREADNOUGHT BOSS (32x32)
# =============================================================================
def draw_mecha_boss(frame=0):
    img = create_canvas(32, 32)
    # Lõi phản vật chất trung tâm đập xung năng lượng Đỏ/Tím Neon
    core_glow = C_PURP_GLOW if frame == 0 else C_RED_NEON
    core_deep = C_PURP_DEEP if frame == 0 else C_RED_DEEP

    # Giáp sừng titan nhọn phía trên
    for y in range(2, 6):
        set_sym(img, 16, y, 3, C_GOLD_ARMOR)
        set_sym(img, 16, y, 4, C_GOLD_DEEP)
        set_sym(img, 16, y, 8, C_STEEL_HI)
        set_sym(img, 16, y, 9, C_STEEL_DK)

    # Lõi năng lượng phát quang ở tâm
    for y in range(6, 13):
        set_sym(img, 16, y, 1, C_CYAN_CORE if frame==1 else core_glow)
        set_sym(img, 16, y, 2, core_glow)
        set_sym(img, 16, y, 3, core_deep)
        for dx in range(4, 8):
            set_sym(img, 16, y, dx, C_PANEL_DK if dx<7 else C_GOLD_ARMOR)

    # Cánh khiên cơ khí khổng lồ xòe ra (Mecha Armor Shields)
    span = 15 if frame == 0 else 13
    for y in range(13, 23):
        set_sym(img, 16, y, 1, C_PANEL_DK)
        set_sym(img, 16, y, 2, core_glow)
        for dx in range(3, span):
            if dx == span - 1: set_sym(img, 16, y, dx, C_GOLD_ARMOR)
            elif dx == span - 2: set_sym(img, 16, y, dx, C_GOLD_DEEP)
            elif dx in [7, 8]: set_sym(img, 16, y, dx, C_STEEL_HI)
            else: set_sym(img, 16, y, dx, C_PANEL_DK)

    # Càng móc hủy diệt phía dưới
    for y in range(23, 29):
        set_sym(img, 16, y, 4, C_STEEL_MID)
        set_sym(img, 16, y, 5, C_STEEL_HI)
        set_sym(img, 16, y, 10 if frame==0 else 9, C_RED_NEON)
        set_sym(img, 16, y, 11 if frame==0 else 10, C_RED_DEEP)

    return img

# =============================================================================
# 3. QUÁI HỘ TỐNG MECHA ĐỎ (PLASMA STALKER - 32x32)
# =============================================================================
def draw_mecha_escort(frame=0):
    img = create_canvas(32, 32)
    # Tàu lưỡi dao đỏ (Forward-swept Red Blades)
    # Đầu dò hồng ngoại & Mũi nhọn
    set_sym(img, 16, 4, 1, C_RED_NEON)
    set_sym(img, 16, 5, 1, C_CYAN_CORE)
    set_sym(img, 16, 5, 2, C_RED_NEON)

    # Thân máy bọc giáp đỏ sẫm góc cạnh
    for y in range(6, 12):
        set_sym(img, 16, y, 1, C_PANEL_DK)
        set_sym(img, 16, y, 2, C_RED_NEON)
        set_sym(img, 16, y, 3, C_CRIMSON)
        set_sym(img, 16, y, 4, C_RED_DEEP)

    # Cánh lưỡi dao laze nhọn hoắt chĩa về phía trước (Forward Swept)
    for y in range(12, 22):
        blade_x = 5 + (y - 12) if frame==0 else 4 + (y - 12)
        set_sym(img, 16, y, 1, C_STEEL_DK)
        set_sym(img, 16, y, 2, C_CRIMSON)
        for dx in range(3, blade_x):
            set_sym(img, 16, y, dx, C_PANEL_DK)
        set_sym(img, 16, y, blade_x, C_RED_NEON)     # Lưỡi cắt Plasma sáng rực
        set_sym(img, 16, y, blade_x+1, C_CYAN_CORE if (y in [16,17]) else C_RED_DEEP)

    # Càng kẹp điện từ dưới đuôi
    for y in range(22, 28):
        pos = (y - 22) + (3 if frame==0 else 2)
        set_sym(img, 16, y, pos, C_RED_NEON)
        set_sym(img, 16, y, pos+1, C_STEEL_MID)

    return img

# =============================================================================
# 4. QUÁI BINH NHÌ MECHA XANH (CYBER WASP DRONE - 32x32)
# =============================================================================
def draw_mecha_drone(frame=0):
    img = create_canvas(32, 32)
    # Drone lục giác chiến thuật với cánh điện từ Lime Green
    # Ăng-ten cảm biến radar
    set_sym(img, 16, 4, 2 if frame==0 else 1, C_LIME_NEON)
    set_sym(img, 16, 5, 1, C_LIME_NEON)

    # Buồng cảm biến mắt thần
    for y in range(6, 11):
        set_sym(img, 16, y, 1, C_CYAN_CORE if frame==1 else C_LIME_NEON)
        set_sym(img, 16, y, 2, C_LIME_NEON)
        set_sym(img, 16, y, 3, C_PANEL_DK)

    # Thân cơ khí lục giác
    for y in range(11, 20):
        set_sym(img, 16, y, 1, C_STEEL_DK)
        w = 8 if (13 <= y <= 17) else 6
        if frame == 1: w += 1
        for dx in range(2, w):
            if dx == w-1: set_sym(img, 16, y, dx, C_LIME_NEON) # Viền cánh điện từ
            elif dx == w-2: set_sym(img, 16, y, dx, C_LIME_DEEP)
            else: set_sym(img, 16, y, dx, C_PANEL_DK)

    # Khớp động cơ đẩy vi mô ở đuôi
    for y in range(20, 26):
        set_sym(img, 16, y, 2 if frame==0 else 3, C_LIME_NEON)
        set_sym(img, 16, y, 4 if frame==0 else 5, C_STEEL_MID)

    return img

# =============================================================================
# 5. VỤ NỔ 64x64 ĐỘC LẬP: ALIEN PLASMA EMP vs PLAYER NUCLEAR MECHA
# =============================================================================
def draw_cyber_alien_explosion(frame=0):
    img = create_canvas(64, 64)
    cx, cy = 31.5, 31.5
    for y in range(64):
        for x in range(64):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            angle = math.atan2(dy, dx)

            # Cấu trúc sóng xung kích EMP hình lục giác (Hexagonal Shockwave)
            hex_wave = 3.0 * math.cos(6 * angle)
            eff_d = d + hex_wave

            if frame == 0:
                # Tia chớp phản vật chất xanh ngọc chói lòa
                if eff_d < 6: img.putpixel((x, y), C_CYAN_CORE)
                elif eff_d < 11: img.putpixel((x, y), C_CYAN_GLOW)
                elif eff_d < 16: img.putpixel((x, y), C_PURP_GLOW)
                elif eff_d < 20 and (x+y)%2==0: img.putpixel((x, y), C_PURP_DEEP)
            elif frame == 1:
                # Bùng nổ cực đại bão EMP lục giác tím rực
                if eff_d < 8: img.putpixel((x, y), C_CYAN_CORE)
                elif eff_d < 15: img.putpixel((x, y), C_CYAN_GLOW)
                elif eff_d < 23: img.putpixel((x, y), C_PURP_GLOW)
                elif eff_d < 29: img.putpixel((x, y), C_PURP_DEEP)
                elif eff_d < 31 and (x^y)%3==0: img.putpixel((x, y), C_LIME_NEON)
            elif frame == 2:
                # Vòng sóng xung kích lục giác mở rộng ra ngoài
                if 16 < eff_d < 24: img.putpixel((x, y), C_CYAN_GLOW)
                elif 10 < eff_d < 17 and (x+y)%2==0: img.putpixel((x, y), C_PURP_GLOW)
                elif 24 < eff_d < 30 and (x*y)%3==0: img.putpixel((x, y), C_PURP_DEEP)
            elif frame == 3:
                # Hạt bụi plasma tan biến rải rác
                if 18 < eff_d < 31 and ((x*7 + y*13) % 6 == 0):
                    img.putpixel((x, y), C_CYAN_GLOW)
                elif 10 < eff_d < 26 and ((x*5 + y*11) % 5 == 0):
                    img.putpixel((x, y), C_PURP_GLOW)
    return img

def draw_cyber_player_explosion(frame=0):
    img = create_canvas(64, 64)
    cx, cy = 31.5, 31.5
    for y in range(64):
        for x in range(64):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            angle = math.atan2(dy, dx)

            # Vết xé toạc thân tàu kim loại 8 hướng
            fracture = 4.5 * math.sin(8 * angle)
            eff_d = d + fracture

            if frame == 0:
                # Chớp nổ trắng xóa toàn màn hình
                if eff_d < 9: img.putpixel((x, y), C_CYAN_CORE)
                elif eff_d < 15: img.putpixel((x, y), C_YELLOW_CORE)
                elif eff_d < 22: img.putpixel((x, y), C_ORANGE_FIRE)
                elif eff_d < 26 and (x+y)%2==0: img.putpixel((x, y), C_RED_NEON)
            elif frame == 1:
                # Cầu lửa nhiệt hạch bùng cực đại tràn mép 64
                if eff_d < 10: img.putpixel((x, y), C_CYAN_CORE)
                elif eff_d < 18: img.putpixel((x, y), C_YELLOW_CORE)
                elif eff_d < 25: img.putpixel((x, y), C_ORANGE_FIRE)
                elif eff_d < 30: img.putpixel((x, y), C_RED_NEON)
                elif eff_d < 32 and (x^y)%2==0: img.putpixel((x, y), C_RED_DEEP)
            elif frame == 2:
                # Khói titan xám đen và mảnh vỡ vỏ hợp kim bắn tung tóe
                if eff_d < 8: img.putpixel((x, y), C_PANEL_DK)
                elif 8 <= eff_d < 16 and (x+y)%2==0: img.putpixel((x, y), C_ORANGE_FIRE)
                elif 16 <= eff_d < 27: img.putpixel((x, y), C_RED_DEEP)
                # Mảnh kim loại phi thuyền trắng bạc văng xa
                elif 25 <= eff_d < 31 and ((x*13 + y*7) % 4 == 0):
                    img.putpixel((x, y), C_STEEL_HI)
            elif frame == 3:
                # Bão tàn tro và bụi khói lơ lửng
                if eff_d < 14 and ((x+y)%3==0): img.putpixel((x, y), C_STEEL_DK)
                elif 14 < eff_d < 29 and ((x*11 + y*19) % 5 == 0):
                    img.putpixel((x, y), C_ORANGE_FIRE)
                elif 18 < eff_d < 31 and ((x*5 + y*7) % 6 == 0):
                    img.putpixel((x, y), C_RED_DEEP)
    return img

def main():
    sprites = {
        # Tàu chiến Interceptor Mecha
        "ship_f0.png": draw_mecha_ship(0),
        "ship_f1.png": draw_mecha_ship(1),
        # Boss Dreadnought
        "boss_f0.png": draw_mecha_boss(0),
        "boss_f1.png": draw_mecha_boss(1),
        # Escort Plasma Stalker
        "escort_f0.png": draw_mecha_escort(0),
        "escort_f1.png": draw_mecha_escort(1),
        # Drone Cyber Wasp
        "drone_f0.png": draw_mecha_drone(0),
        "drone_f1.png": draw_mecha_drone(1),
        # Vụ nổ quái ngoài hành tinh 64x64
        "alien_exp_f0.png": draw_cyber_alien_explosion(0),
        "alien_exp_f1.png": draw_cyber_alien_explosion(1),
        "alien_exp_f2.png": draw_cyber_alien_explosion(2),
        "alien_exp_f3.png": draw_cyber_alien_explosion(3),
        # Vụ nổ tàu ta 64x64
        "player_exp_f0.png": draw_cyber_player_explosion(0),
        "player_exp_f1.png": draw_cyber_player_explosion(1),
        "player_exp_f2.png": draw_cyber_player_explosion(2),
        "player_exp_f3.png": draw_cyber_player_explosion(3),
    }

    print("==========================================================")
    print("Vẽ lại 100% Bộ Đồ Họa Cyberpunk / Sci-Fi Mecha Đột Phá:")
    print("==========================================================")
    for name, img in sprites.items():
        out_p = OUT_DIR / name
        img.save(out_p)
        print(f" [V] Đã tạo sprite: {out_p.name} ({img.width}x{img.height} RGBA)")

if __name__ == "__main__":
    main()
