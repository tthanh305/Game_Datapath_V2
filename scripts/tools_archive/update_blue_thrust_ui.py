"""Update selection UI with blue snug thruster."""
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

combat_demo_gif = b64("combat_vfx_snug_blue.gif")
ship_snug_gif = b64("ship_snug_blue_thrust.gif")
blue_strip = b64_png("blue_thrust_8f_strip.png")
bullet_strip = b64_png("energy_bullet_strip.png")
rico_strip = b64_png("ricochet_4f_strip.png")

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
        <span class="w-2.5 h-2.5 rounded-full bg-cyan-400"></span>
        Hiệu Ứng Lửa Đuôi Xanh Cyan Đã Căn Chỉnh Sát Đuôi Tàu
      </h2>
      <p class="text-[var(--muted-foreground)] text-xs mt-1">
        Trích xuất từ <code class="text-cyan-400 font-mono">pixel-art-jetpack-thrust-blue-sheet.png</code> và căn chỉnh khớp hoàn toàn với nòng xả:
      </p>
    </div>

    <!-- Live Unified Demo -->
    <div class="flex flex-col md:flex-row items-center gap-5 p-4 rounded-xl border border-cyan-500/30 bg-[#080612]">
      <img src="{combat_demo_gif}" class="w-48 h-40 object-contain rounded-lg border border-cyan-500/40 bg-black/60 shadow-lg" />
      <div class="space-y-2 text-xs text-[var(--muted-foreground)]">
        <span class="px-2.5 py-1 rounded-full text-[11px] font-bold bg-cyan-500/20 text-cyan-300 border border-cyan-500/40 inline-block">
          HOẠT ẢNH CHIẾN ĐẤU HOÀN THIỆN
        </span>
        <p class="text-[var(--foreground)] font-semibold text-sm">
          Đồng bộ các hiệu ứng từ thư mục /gif/:
        </p>
        <p>1. <strong class="text-cyan-400">Đuôi phóng Blue Plasma</strong>: Phụt trực tiếp từ nòng xả, không còn khe hở, đổi góc mượt theo độ nghiêng tàu.</p>
        <p>2. <strong class="text-pink-400">Đạn năng lượng Energy Bullet</strong>: Tím hồng phát sáng, bay thẳng 60Hz.</p>
        <p>3. <strong class="text-amber-400">Tia lửa Ricochet kim loại</strong>: Tóe xòe đanh thép khi trúng giáp quái.</p>
        <p>4. <strong class="text-emerald-400">Vụ nổ êm dịu Fireball</strong>: Tan thành khói xám, hoàn toàn không gây lóa mắt.</p>
      </div>
    </div>

    <!-- Detailed Alignment Card -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      
      <!-- Blue Thrust Snug Docking -->
      <div class="p-3.5 rounded-xl border border-cyan-500/30 bg-[var(--background)]/40 flex items-center gap-4">
        <img src="{ship_snug_gif}" class="w-20 h-20 object-contain rounded border border-cyan-500/30 bg-black/50" />
        <div class="text-xs text-[var(--muted-foreground)] space-y-1">
          <p class="text-[var(--foreground)] font-semibold">Căn Chỉnh Sát Nòng Tàu (Flush Docking)</p>
          <p>• Tọa độ <code class="text-cyan-400 font-mono">ship_y + 22</code> đưa gốc ngọn lửa luồn vào dưới nòng xả kim loại.</p>
          <p>• Khi tàu nghiêng trái/phải, luồng lửa tự động dịch chuyển góc nghiêng tương ứng.</p>
        </div>
      </div>

      <!-- 8 Frames Strip -->
      <div class="p-3.5 rounded-xl border border-[var(--border)] bg-[var(--background)]/40 space-y-2">
        <div class="flex items-center justify-between text-xs">
          <span class="font-semibold text-[var(--foreground)]">Chuỗi 8 frame Lửa Phản Lực Xanh:</span>
          <span class="text-[10px] text-cyan-400 font-mono">16×20 px</span>
        </div>
        <img src="{blue_strip}" class="h-6 object-contain bg-black/40 rounded p-1 border border-border" />
      </div>

    </div>

  </div>
</body>
</html>
"""

(out_dir / "gif_effects_selection.html").write_text(html, encoding="utf-8")
print("Updated gif_effects_selection.html with blue thruster!")

