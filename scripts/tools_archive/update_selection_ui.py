"""Update the interactive selection UI with ricochet and gold thrust."""
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

rico_combat_gif = b64("ricochet_hit_combat_demo.gif")
rico_strip = b64_png("ricochet_4f_strip.png")

thrust_ship_gif = b64("ship_gold_thrust_demo.gif")
thrust_strip = b64_png("gold_thrust_8f_strip.png")

fb_gif = b64("opt_fireball_8f.gif")
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
        <span class="w-2.5 h-2.5 rounded-full bg-amber-400"></span>
        Bộ Hiệu Ứng Trúng Đạn & Tên Lửa Bạn Đã Chọn Từ /gif/
      </h2>
      <p class="text-[var(--muted-foreground)] text-xs mt-1">
        Đã trích xuất và tinh chỉnh kích thước chuẩn pixel-art cho phần cứng FPGA (EBAZ4205):
      </p>
    </div>

    <!-- 2 Main Chosen Assets -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      
      <!-- Asset 1: Ricochet Metal Hit Effect -->
      <div class="p-4 rounded-xl border border-cyan-500/40 bg-[var(--background)]/40 shadow-sm space-y-3">
        <div class="flex items-center justify-between">
          <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-cyan-500/20 text-cyan-300 border border-cyan-500/40">
            HIỆU ỨNG TRÚNG ĐẠN (RICOCHET)
          </span>
          <span class="text-xs text-[var(--muted-foreground)]">4 frames (32×32)</span>
        </div>
        <div class="flex items-center gap-4 bg-[#0a0812] p-3 rounded-lg border border-[var(--border)]">
          <img src="{rico_combat_gif}" class="w-28 h-20 object-contain rounded border border-cyan-500/30 bg-black/60" />
          <div class="text-xs text-[var(--muted-foreground)] space-y-1">
            <p class="text-[var(--foreground)] font-semibold">Tia Lửa Kim Loại Ricochet</p>
            <p>• Trích xuất từ <code class="text-cyan-400 font-mono">ricochet-metal-sheet.png</code></p>
            <p>• Tóe tia lửa vàng cam đanh thép khi đạn chạm giáp tàu.</p>
            <p class="text-emerald-400 font-medium">✓ Đã tắt hoàn toàn chớp trắng lóa mắt.</p>
          </div>
        </div>
        <div>
          <p class="text-[11px] text-[var(--muted-foreground)] mb-1">Chuỗi 4 frame Ricochet:</p>
          <img src="{rico_strip}" class="h-8 object-contain bg-black/40 rounded p-1 border border-border" />
        </div>
      </div>

      <!-- Asset 2: Gold Jetpack Rocket Thrust -->
      <div class="p-4 rounded-xl border border-yellow-500/40 bg-[var(--background)]/40 shadow-sm space-y-3">
        <div class="flex items-center justify-between">
          <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-yellow-500/20 text-yellow-300 border border-yellow-500/40">
            HIỆU ỨNG TÊN LỬA / ĐỘNG CƠ
          </span>
          <span class="text-xs text-[var(--muted-foreground)]">4-8 frames (16×24)</span>
        </div>
        <div class="flex items-center gap-4 bg-[#0a0812] p-3 rounded-lg border border-[var(--border)]">
          <img src="{thrust_ship_gif}" class="w-20 h-20 object-contain rounded border border-yellow-500/30 bg-black/60" />
          <div class="text-xs text-[var(--muted-foreground)] space-y-1">
            <p class="text-[var(--foreground)] font-semibold">Lửa Phản Lực Vàng Kim</p>
            <p>• Trích xuất từ <code class="text-yellow-400 font-mono">pixel-art-jetpack-thrust-gold-sheet.png</code></p>
            <p>• Luồng lửa phụt đuôi tàu cuộn sóng nhịp nhàng 60Hz.</p>
            <p class="text-emerald-400 font-medium">✓ Tông màu vàng kim ấm áp, cổ điển.</p>
          </div>
        </div>
        <div>
          <p class="text-[11px] text-[var(--muted-foreground)] mb-1">Chuỗi 8 frame Lửa Tên Lửa:</p>
          <img src="{thrust_strip}" class="h-6 object-contain bg-black/40 rounded p-1 border border-border" />
        </div>
      </div>

    </div>

    <!-- Explosion Option -->
    <div class="p-4 rounded-xl border border-amber-500/30 bg-[var(--background)]/30 flex items-center justify-between">
      <div class="flex items-center gap-4">
        <img src="{fb_gif}" class="w-14 h-14 object-contain rounded border border-amber-500/30 bg-black/60" />
        <div class="text-xs text-[var(--muted-foreground)] space-y-0.5">
          <p class="text-[var(--foreground)] font-semibold">Vụ Nổ Cầu Lửa Êm Dịu (Midair Fireball)</p>
          <p>Trích xuất 8 frame từ <code class="text-amber-400 font-mono">midair-fireball-explosion.gif</code> thay thế cho vụ nổ chớp cũ.</p>
          <p class="text-emerald-400 font-medium">✓ Không rung chớp màn hình, không lóa mắt.</p>
        </div>
      </div>
      <img src="{fb_strip}" class="h-8 object-contain bg-black/40 rounded p-1 border border-border hidden md:block" />
    </div>

  </div>
</body>
</html>
"""

(out_dir / "gif_effects_selection.html").write_text(html, encoding="utf-8")
print("Updated gif_effects_selection.html")

