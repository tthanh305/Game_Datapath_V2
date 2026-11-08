"""Generate an interactive HTML artifact showing the extracted effects from gif folder."""
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

fb_gif = b64("opt_fireball_8f.gif")
imp_gif = b64("opt_energy_impact.gif")
ast_gif = b64("opt_asteroid_exp.gif")
fuel_gif = b64("opt_fuel_blast.gif")
thrust_gif = b64("opt_gold_thrust.gif")

fb_strip = b64_png("fireball_8f_strip.png")
imp_strip = b64_png("energy_impact_6f_strip.png")
ast_strip = b64_png("asteroid_exp_6f_strip.png")

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
        Bộ Hiệu Ứng Được Trích Xuất Từ Thư Mục /gif/
      </h2>
      <p class="text-[var(--muted-foreground)] text-xs mt-1">
        Đã loại bỏ hoàn toàn hiện tượng chớp trắng toàn màn hình và tia sáng ngang gây chói mắt. Dưới đây là các phương án tối ưu:
      </p>
    </div>

    <!-- Grid of Options -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      
      <!-- Option 1: Midair Fireball Explosion -->
      <div class="p-4 rounded-xl border border-[var(--border)] bg-[var(--background)]/40 hover:border-amber-500/50 transition">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-amber-500/20 text-amber-400 border border-amber-500/30">
              ĐỀ XUẤT #1: VỤ NỔ QUÁI / BOSS
            </span>
          </div>
          <span class="text-xs text-[var(--muted-foreground)]">8 frames (48×48)</span>
        </div>
        <div class="flex items-center gap-4 my-3 bg-[#0a0812] p-3 rounded-lg border border-[var(--border)]">
          <img src="{fb_gif}" class="w-16 h-16 object-contain border border-amber-500/30 rounded p-1 bg-black/50" />
          <div class="text-xs text-[var(--muted-foreground)] space-y-1">
            <p class="text-[var(--foreground)] font-semibold">Midair Fireball Explosion</p>
            <p>• Cầu lửa vàng cam cuộn tròn tự nhiên, tan biến thành khói xám nhẹ.</p>
            <p>• <strong class="text-emerald-400">Không chớp màn hình, dịu mắt, độ mượt 60Hz.</strong></p>
          </div>
        </div>
        <div class="overflow-x-auto pb-1">
          <p class="text-[11px] text-[var(--muted-foreground)] mb-1">Chuỗi 8 frame trích xuất:</p>
          <img src="{fb_strip}" class="h-10 object-contain bg-black/40 rounded p-1 border border-border" />
        </div>
      </div>

      <!-- Option 2: Energy Bullet Impact -->
      <div class="p-4 rounded-xl border border-[var(--border)] bg-[var(--background)]/40 hover:border-cyan-500/50 transition">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">
              ĐỀ XUẤT #2: HIỆU ỨNG TRÚNG ĐẠN (HIT VFX)
            </span>
          </div>
          <span class="text-xs text-[var(--muted-foreground)]">6 frames (32×32)</span>
        </div>
        <div class="flex items-center gap-4 my-3 bg-[#0a0812] p-3 rounded-lg border border-[var(--border)]">
          <img src="{imp_gif}" class="w-16 h-16 object-contain border border-cyan-500/30 rounded p-1 bg-black/50" />
          <div class="text-xs text-[var(--muted-foreground)] space-y-1">
            <p class="text-[var(--foreground)] font-semibold">Energy Bullet Impact</p>
            <p>• Vòng sóng năng lượng nổ bung tỏa ra khi đạn chạm vào tàu địch.</p>
            <p>• Thay thế cho Hit Flash trắng gắt, phản hồi trúng đạn rõ ràng.</p>
          </div>
        </div>
        <div class="overflow-x-auto pb-1">
          <p class="text-[11px] text-[var(--muted-foreground)] mb-1">Chuỗi 6 frame trích xuất:</p>
          <img src="{imp_strip}" class="h-8 object-contain bg-black/40 rounded p-1 border border-border" />
        </div>
      </div>

      <!-- Option 3: Asteroid Shatter Explosion -->
      <div class="p-4 rounded-xl border border-[var(--border)] bg-[var(--background)]/40 hover:border-emerald-500/50 transition">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
              ĐỀ XUẤT #3: VỠ THIÊN THẠCH
            </span>
          </div>
          <span class="text-xs text-[var(--muted-foreground)]">6 frames (32×32)</span>
        </div>
        <div class="flex items-center gap-4 my-3 bg-[#0a0812] p-3 rounded-lg border border-[var(--border)]">
          <img src="{ast_gif}" class="w-16 h-16 object-contain border border-emerald-500/30 rounded p-1 bg-black/50" />
          <div class="text-xs text-[var(--muted-foreground)] space-y-1">
            <p class="text-[var(--foreground)] font-semibold">Asteroid Debris Shatter</p>
            <p>• Thiên thạch vỡ vụn thành các mảnh đá nhỏ văng ra nhiều hướng.</p>
            <p>• Rất tự nhiên cho các vật thể môi trường vũ trụ.</p>
          </div>
        </div>
        <div class="overflow-x-auto pb-1">
          <p class="text-[11px] text-[var(--muted-foreground)] mb-1">Chuỗi 6 frame trích xuất:</p>
          <img src="{ast_strip}" class="h-8 object-contain bg-black/40 rounded p-1 border border-border" />
        </div>
      </div>

      <!-- Option 4: Gold Jetpack Thruster Flame -->
      <div class="p-4 rounded-xl border border-[var(--border)] bg-[var(--background)]/40 hover:border-yellow-500/50 transition">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-yellow-500/20 text-yellow-400 border border-yellow-500/30">
              ĐỀ XUẤT #4: LỬA PHẢN LỰC TÀU
            </span>
          </div>
          <span class="text-xs text-[var(--muted-foreground)]">4-8 frames (16×24)</span>
        </div>
        <div class="flex items-center gap-4 my-3 bg-[#0a0812] p-3 rounded-lg border border-[var(--border)]">
          <img src="{thrust_gif}" class="w-16 h-16 object-contain border border-yellow-500/30 rounded p-1 bg-black/50" />
          <div class="text-xs text-[var(--muted-foreground)] space-y-1">
            <p class="text-[var(--foreground)] font-semibold">Gold Jetpack Thruster</p>
            <p>• Ngọn lửa phản lực vàng kim óng ánh, phun nhịp nhàng ở đuôi phi thuyền.</p>
            <p>• Tông màu cổ điển ấm áp, tương phản rất đẹp với nền không gian đen-xanh.</p>
          </div>
        </div>
      </div>

    </div>

    <!-- Summary of Changes -->
    <div class="bg-[var(--background)] p-4 rounded-xl border border-[var(--border)] text-xs text-[var(--muted-foreground)] space-y-1.5">
      <div class="font-semibold text-[var(--foreground)] flex items-center gap-1.5">
        <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
        Kế hoạch điều chỉnh triệt để loại bỏ cảm giác chói mắt:
      </div>
      <p>1. <strong class="text-rose-400">Tắt hoàn toàn Impact Screen Flash</strong>: Không làm sáng rực toàn màn hình nữa.</p>
      <p>2. <strong class="text-rose-400">Tắt Anamorphic Lens Flare</strong>: Bỏ dải sáng ngang màn hình.</p>
      <p>3. <strong class="text-emerald-400">Thay vụ nổ bằng Midair Fireball (8 frame)</strong>: Cầu lửa nổ bùng mượt mà, màu sắc hài hòa, cổ điển.</p>
      <p>4. <strong class="text-cyan-400">Dùng Energy Bullet Impact (6 frame)</strong> cho điểm đạn va chạm thay vì chớp trắng giật mắt.</p>
    </div>

  </div>
</body>
</html>
"""

(out_dir / "gif_effects_selection.html").write_text(html, encoding="utf-8")
print("Saved gif_effects_selection.html")

