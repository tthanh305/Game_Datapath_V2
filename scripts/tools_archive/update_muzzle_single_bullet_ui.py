"""Update selection UI with single bullet and muzzle flash."""
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

combat_demo_gif = b64("single_bullet_muzzle_demo.gif")
closeup_gif = b64("ship_firing_closeup.gif")
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
        <span class="w-2.5 h-2.5 rounded-full bg-cyan-400"></span>
        Đạn 1 Tia & Chớp Nòng Muzzle Flash Khớp Nòng Máy Bay
      </h2>
      <p class="text-[var(--muted-foreground)] text-xs mt-1">
        Căn chỉnh chính xác theo yêu cầu: Đạn 1 tia trung tâm, Muzzle Flash khớp mũi máy bay và Lửa đuôi Blue Plasma sát nòng xả:
      </p>
    </div>

    <!-- 2 Live Demos -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      
      <!-- Demo 1: Close-up Docking Inspection -->
      <div class="p-4 rounded-xl border border-cyan-500/30 bg-[#0a0814] flex flex-col items-center text-center space-y-2">
        <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
          CẬN CẢNH MÁY BAY: NÒNG TRƯỚC & ĐUÔI XẢ
        </span>
        <img src="{closeup_gif}" class="w-28 h-36 object-contain rounded border border-cyan-500/30 bg-black/50 p-1" />
        <div class="text-xs text-[var(--muted-foreground)] space-y-0.5">
          <p class="text-[var(--foreground)] font-semibold">Khớp Hoàn Hảo Cả 2 Đầu:</p>
          <p>• <strong>Mũi trước</strong>: Muzzle Flash nổ ngay đầu nòng pháo.</p>
          <p>• <strong>Đạn 1 tia</strong>: Phun thẳng từ tâm mũi máy bay.</p>
          <p>• <strong>Đuôi sau</strong>: Lửa Blue Plasma luồn sát ống xả.</p>
        </div>
      </div>

      <!-- Demo 2: Full Combat Action -->
      <div class="p-4 rounded-xl border border-pink-500/30 bg-[#0a0814] flex flex-col items-center text-center space-y-2">
        <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-pink-500/20 text-pink-300 border border-pink-500/30">
          CHIẾN ĐẤU THỰC TẾ TRONG GAME
        </span>
        <img src="{combat_demo_gif}" class="w-48 h-36 object-contain rounded border border-pink-500/30 bg-black/50 p-1" />
        <div class="text-xs text-[var(--muted-foreground)] space-y-0.5">
          <p class="text-[var(--foreground)] font-semibold">Chuỗi Tác Động Liền Mạch:</p>
          <p>Bắn đạn 1 tia $\rightarrow$ Muzzle Flash $\rightarrow$ Trúng đích tóe tia lửa Ricochet $\rightarrow$ Nổ êm dịu.</p>
          <p class="text-emerald-400 font-medium">✓ Hoàn toàn không lóa mắt, êm dịu 60Hz.</p>
        </div>
      </div>

    </div>

    <!-- Strips -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3 pt-1">
      <div class="p-2.5 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1">
        <span class="font-bold text-xs text-cyan-400">Đạn 1 Tia Plasma</span>
        <img src="{bullet_strip}" class="h-6 object-contain bg-black/40 rounded p-0.5 border border-border" />
      </div>
      <div class="p-2.5 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1">
        <span class="font-bold text-xs text-amber-400">Tia Lửa Ricochet</span>
        <img src="{rico_strip}" class="h-6 object-contain bg-black/40 rounded p-0.5 border border-border" />
      </div>
      <div class="p-2.5 rounded-lg border border-[var(--border)] bg-[var(--background)]/40 space-y-1">
        <span class="font-bold text-xs text-blue-400">Đuôi Phóng Sát Nòng</span>
        <img src="{blue_strip}" class="h-6 object-contain bg-black/40 rounded p-0.5 border border-border" />
      </div>
    </div>

  </div>
</body>
</html>
"""

(out_dir / "gif_effects_selection.html").write_text(html, encoding="utf-8")
print("Updated gif_effects_selection.html with close-up and single bullet!")

