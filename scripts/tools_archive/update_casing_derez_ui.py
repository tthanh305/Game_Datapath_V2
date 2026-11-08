"""Update selection UI with casings and digital derez."""
import base64
from pathlib import Path

out_dir = Path(r"C:\Users\thanh\.gemini\antigravity/brain/58b47c13-6381-4da7-810e-6c0c0feae7de")

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

combat_demo_gif = b64("derez_casing_combat_showcase.gif")
casing_closeup_gif = b64("casing_ejection_closeup.gif")
derez_strip = b64_png("digital_derez_6f_strip.png")
casing_spin_gif = b64("bullet_casing_spin.gif")
boss_strip = b64_png("boss_exp_8f_strip.png")

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
        Vỏ Đạn Văng & Trúng Địch Digital Derez Đã Tích Hợp
      </h2>
      <p class="text-[var(--muted-foreground)] text-xs mt-1">
        Trích xuất từ <code class="text-amber-400 font-mono">rifle-burst-sheet.png</code> (vỏ đạn) và <code class="text-cyan-400 font-mono">digital-derez-sheet.png</code> (trúng địch):
      </p>
    </div>

    <!-- 2 Main Demos -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      
      <!-- Demo 1: Casing Ejection Close-up -->
      <div class="p-4 rounded-xl border border-amber-500/40 bg-[#0a0814] flex flex-col items-center text-center space-y-2">
        <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500/20 text-amber-300 border border-amber-500/30">
          1. BẮN VĂNG VỎ ĐẠN KIM LOẠI (CASINGS)
        </span>
        <img src="{casing_closeup_gif}" class="w-32 h-36 object-contain rounded border border-amber-500/30 bg-black/50 p-1" />
        <div class="text-xs text-[var(--muted-foreground)] space-y-1">
          <p class="text-[var(--foreground)] font-semibold">Cơ Khí Văng Vỏ Đạn Sắc Nét:</p>
          <p>• Khi khai hỏa, vỏ đạn đồng vàng hất văng ra từ cửa buồng đạn bên phải phi thuyền, xoay tròn 4 góc rơi về phía sau.</p>
          <p class="text-amber-400 font-medium">✓ Cảm giác cơ khí chân thực chuẩn Arcade!</p>
        </div>
      </div>

      <!-- Demo 2: Digital Derez Hit & Explosion -->
      <div class="p-4 rounded-xl border border-cyan-500/40 bg-[#080612] flex flex-col items-center text-center space-y-2">
        <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
          2. TRÚNG ĐỊCH DIGITAL DEREZ & PHÁT NỔ
        </span>
        <img src="{combat_demo_gif}" class="w-48 h-36 object-contain rounded border border-cyan-500/30 bg-black/50 p-1" />
        <div class="text-xs text-[var(--muted-foreground)] space-y-1">
          <p class="text-[var(--foreground)] font-semibold">Tác Động Ma Trận Số Hóa:</p>
          <p>• Đạn chạm giáp: Tàu địch bị số hóa thành ma trận voxel Cyan neon vỡ vụn, hòa vào đám lửa nổ của Boss.</p>
          <p class="text-emerald-400 font-medium">✓ Ăn khớp tức thì 0 delay, êm mắt tuyệt đối.</p>
        </div>
      </div>

    </div>

    <!-- Strips -->
    <div class="space-y-3">
      <!-- Derez Strip -->
      <div class="p-3 rounded-xl border border-cyan-500/30 bg-[var(--background)]/40 space-y-1.5">
        <div class="flex items-center justify-between text-xs">
          <span class="font-bold text-cyan-400 flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-cyan-400"></span>
            Chuỗi 6 Frame Digital Derez Trúng Địch (Ma trận điểm ảnh số hóa):
          </span>
          <span class="text-[10px] text-cyan-400 font-mono">digital-derez-sheet.png</span>
        </div>
        <img src="{derez_strip}" class="h-8 object-contain bg-black/50 rounded p-1 border border-border" />
      </div>

      <!-- Boss Strip -->
      <div class="p-3 rounded-xl border border-amber-500/30 bg-[var(--background)]/40 space-y-1.5">
        <div class="flex items-center justify-between text-xs">
          <span class="font-bold text-amber-400 flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-amber-400"></span>
            Chuỗi 8 Frame Vụ Nổ Boss Êm Dịu:
          </span>
          <span class="text-[10px] text-amber-400 font-mono">pixel-art-boss-explosion-sheet.png</span>
        </div>
        <img src="{boss_strip}" class="h-8 object-contain bg-black/50 rounded p-1 border border-border" />
      </div>
    </div>

  </div>
</body>
</html>
"""

(out_dir / "gif_effects_selection.html").write_text(html, encoding="utf-8")
print("Updated gif_effects_selection.html with casing and derez!")

