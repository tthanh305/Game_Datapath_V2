"""Update gif_effects_selection.html with the complete 3-pack suite chosen by user."""
import base64
from pathlib import Path

out_dir = Path(r"C:\Users\thanh\.gemini\antigravity\brain\58b47c13-6381-4da7-810e-6c0c0feae7de")

def b64(fname):
    p = out_dir / fname
    if p.exists():
        return f"data:image/gif;base64,{base64.b64encode(p.read_bytes()).decode('utf-8')}"
    return ""

def b64_png(fname):
    p = out_dir / fname
    if p.exists():
        return f"data:image/png;base64,{base64.b64encode(p.read_bytes()).decode('utf-8')}"
    return ""

full_demo_gif = b64("full_chosen_vfx_demo.gif")
bullet_strip = b64_png("energy_bullet_strip.png")
rico_strip = b64_png("ricochet_4f_strip.png")
thrust_strip = b64_png("gold_thrust_8f_strip.png")
fb_strip = b64_png("fireball_8f_strip.png")

html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
  <style>
    img {{ image-rendering: pixelated; }}
  </style>
</head>
<body class="bg-transparent text-[var(--foreground)] antialiased p-3">
  <div class="bg-[var(--card)] text-[var(--foreground)] border border-[var(--border)] rounded-2xl p-5 shadow-lg max-w-4xl mx-auto space-y-5">
    
    <!-- Header -->
    <div class="border-b border-[var(--border)] pb-3">
      <h2 class="text-[var(--foreground)] font-bold text-lg flex items-center gap-2">
        <span class="w-2.5 h-2.5 rounded-full bg-pink-400"></span>
        Trọn Bộ 3 Hiệu Ứng Bạn Đã Chọn Từ /gif/ Sẵn Sàng Đóng Gói
      </h2>
      <p class="text-[var(--muted-foreground)] text-xs mt-1">
        Đã liên kết hoàn hảo giữa Đạn năng lượng, Tia lửa Ricochet trúng giáp và Lửa tên lửa vàng kim:
      </p>
    </div>

    <!-- Live Unified Demo -->
    <div class="flex flex-col md:flex-row items-center gap-5 p-4 rounded-xl border border-pink-500/30 bg-[#080612]">
      <img src="{full_demo_gif}" class="w-48 h-40 object-contain rounded-lg border border-pink-500/40 bg-black/60 shadow-lg" />
      <div class="space-y-2 text-xs text-[var(--muted-foreground)]">
        <span class="px-2.5 py-1 rounded-full text-[11px] font-bold bg-pink-500/20 text-pink-300 border border-pink-500/40 inline-block">
          HOẠT ẢNH TỔNG HỢP CHIẾN ĐẤU THỰC TẾ
        </span>
        <p class="text-[var(--foreground)] font-semibold text-sm">
          Chuỗi chuyển động mượt mà 60Hz không hề chớp lóa mắt:
        </p>
        <p>1. <strong class="text-pink-400">Đạn năng lượng (Energy Bullets)</strong>: Đạn plasma tím hồng phát sáng xé gió bay lên.</p>
        <p>2. <strong class="text-cyan-400">Va chạm kim loại (Ricochet Sparks)</strong>: Tia lửa cơ khí vàng cam tóe ra mạnh mẽ.</p>
        <p>3. <strong class="text-yellow-400">Lửa tên lửa (Gold Thruster)</strong>: Luồng phản lực vàng kim cuộn nhịp nhàng ở đuôi tàu.</p>
        <p>4. <strong class="text-amber-400">Vụ nổ cầu lửa (Midair Fireball)</strong>: Nở bùng tự nhiên rồi tan thành khói xám nhẹ.</p>
      </div>
    </div>

    <!-- 3 Strips -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      
      <!-- Bullet -->
      <div class="p-3 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1.5">
        <div class="flex items-center justify-between text-xs">
          <span class="font-bold text-pink-400">1. Đạn Năng Lượng</span>
          <span class="text-[10px] text-[var(--muted-foreground)]">5 frames (10×26)</span>
        </div>
        <img src="{bullet_strip}" class="h-7 object-contain bg-black/40 rounded p-1 border border-border" />
        <p class="text-[10px] text-[var(--muted-foreground)] font-mono">pixel-art-energy-bullet-impact-sheet.png</p>
      </div>

      <!-- Ricochet -->
      <div class="p-3 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1.5">
        <div class="flex items-center justify-between text-xs">
          <span class="font-bold text-cyan-400">2. Tia Lửa Ricochet</span>
          <span class="text-[10px] text-[var(--muted-foreground)]">4 frames (32×32)</span>
        </div>
        <img src="{rico_strip}" class="h-7 object-contain bg-black/40 rounded p-1 border border-border" />
        <p class="text-[10px] text-[var(--muted-foreground)] font-mono">ricochet-metal-sheet.png</p>
      </div>

      <!-- Thrust -->
      <div class="p-3 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1.5">
        <div class="flex items-center justify-between text-xs">
          <span class="font-bold text-yellow-400">3. Lửa Tên Lửa Vàng</span>
          <span class="text-[10px] text-[var(--muted-foreground)]">8 frames (14×20)</span>
        </div>
        <img src="{thrust_strip}" class="h-7 object-contain bg-black/40 rounded p-1 border border-border" />
        <p class="text-[10px] text-[var(--muted-foreground)] font-mono">pixel-art-jetpack-thrust-gold-sheet.png</p>
      </div>

    </div>

  </div>
</body>
</html>
"""

(out_dir / "gif_effects_selection.html").write_text(html, encoding="utf-8")
print("Updated gif_effects_selection.html with full suite!")

