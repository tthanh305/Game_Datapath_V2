"""Update selection UI with zero delay and 8-frame boss explosion."""
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

zero_delay_gif = b64("zero_delay_combat_showcase.gif")
closeup_gif = b64("ship_firing_closeup.gif")
boss_strip = b64_png("boss_exp_8f_strip.png")
bullet_strip = b64_png("energy_bullet_strip.png")
rico_strip = b64_png("ricochet_4f_strip.png")
blue_strip = b64_png("blue_thrust_8f_strip.png")

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
        <span class="w-2.5 h-2.5 rounded-full bg-emerald-400"></span>
        Vụ Nổ Quái Boss & Trúng Đích Tức Thì (Zero-Delay Synchronization)
      </h2>
      <p class="text-[var(--muted-foreground)] text-xs mt-1">
        Trích xuất 8 frame tối ưu từ <code class="text-amber-400 font-mono">pixel-art-boss-explosion-sheet.png</code> và triệt tiêu hoàn toàn độ trễ trúng đạn:
      </p>
    </div>

    <!-- Main Comparison -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      
      <!-- Demo 1: Zero-Delay Explosion Action -->
      <div class="p-4 rounded-xl border border-emerald-500/40 bg-[#080612] flex flex-col items-center text-center space-y-2">
        <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
          ĂN KHỚP TỨC THÌ (ZERO DELAY)
        </span>
        <img src="{zero_delay_gif}" class="w-48 h-40 object-contain rounded border border-emerald-500/30 bg-black/50 p-1" />
        <div class="text-xs text-[var(--muted-foreground)] space-y-1">
          <p class="text-[var(--foreground)] font-semibold">Đạn Chạm Là Nổ Ngay Lập Tức:</p>
          <p>• Đúng chu kỳ đạn chạm giáp: Tàu địch lập tức biến mất, tia lửa Ricochet và ngọn lửa nổ bùng phát <strong>đồng thời 100%</strong>.</p>
          <p class="text-emerald-400 font-medium">✓ Không chờ đợi, cảm giác va chạm cực kỳ đanh và uy lực!</p>
        </div>
      </div>

      <!-- Demo 2: Ship Nose & Exhaust Flush Alignment -->
      <div class="p-4 rounded-xl border border-cyan-500/30 bg-[#0a0814] flex flex-col items-center text-center space-y-2">
        <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
          CẬN CẢNH MÁY BAY: NÒNG & ĐUÔI SÁT KHỚP
        </span>
        <img src="{closeup_gif}" class="w-32 h-40 object-contain rounded border border-cyan-500/30 bg-black/50 p-1" />
        <div class="text-xs text-[var(--muted-foreground)] space-y-1">
          <p class="text-[var(--foreground)] font-semibold">Căn Chỉnh Khớp Tuyệt Đối:</p>
          <p>• Muzzle Flash bùng phát ngay tại đầu nòng pháo mũi tàu.</p>
          <p>• Lửa Blue Plasma luồn sát đáy ống xả kim loại, không khe hở.</p>
        </div>
      </div>

    </div>

    <!-- 8 Frames Strip of Boss Explosion -->
    <div class="p-4 rounded-xl border border-amber-500/30 bg-[var(--background)]/40 space-y-2">
      <div class="flex items-center justify-between text-xs">
        <span class="font-bold text-[var(--foreground)] flex items-center gap-2">
          <span class="w-2 h-2 rounded-full bg-amber-400"></span>
          Chuỗi 8 Frame Vụ Nổ Boss Đã Chọn (Phát nổ vàng rực $\rightarrow$ Cầu lửa cam $\rightarrow$ Khói xám tan biến):
        </span>
        <span class="text-[10px] text-amber-400 font-mono">48×48 px</span>
      </div>
      <div class="overflow-x-auto pb-1">
        <img src="{boss_strip}" class="h-11 object-contain bg-black/50 rounded p-1 border border-border" />
      </div>
    </div>

    <!-- Sub-strips -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="p-2.5 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1 text-center">
        <span class="font-bold text-xs text-pink-400">Đạn 1 Tia Plasma</span>
        <img src="{bullet_strip}" class="h-5 object-contain mx-auto bg-black/40 rounded p-0.5 border border-border" />
      </div>
      <div class="p-2.5 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1 text-center">
        <span class="font-bold text-xs text-cyan-400">Tia Lửa Ricochet</span>
        <img src="{rico_strip}" class="h-5 object-contain mx-auto bg-black/40 rounded p-0.5 border border-border" />
      </div>
      <div class="p-2.5 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1 text-center">
        <span class="font-bold text-xs text-blue-400">Đuôi Phóng Blue Plasma</span>
        <img src="{blue_strip}" class="h-5 object-contain mx-auto bg-black/40 rounded p-0.5 border border-border" />
      </div>
    </div>

  </div>
</body>
</html>
"""

(out_dir / "gif_effects_selection.html").write_text(html, encoding="utf-8")
print("Updated gif_effects_selection.html with zero delay and 8-frame boss explosion!")

