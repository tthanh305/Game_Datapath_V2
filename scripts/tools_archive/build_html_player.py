"""Build a self-contained interactive Steredenn VFX HTML player with embedded Base64 sprites."""
import base64
from pathlib import Path

st_dir = Path("assets/sprites/steredenn")
sp_dir = Path("assets/sprites")

def to_b64(path):
    if path.exists():
        return f"data:image/png;base64,{base64.b64encode(path.read_bytes()).decode('utf-8')}"
    return ""

exp_frames = [to_b64(st_dir / f"steredenn_exp_f{i}.png") for i in range(16)]
ship_banks = [to_b64(st_dir / f"ship_bank_f{i}.png") for i in range(5)]
thrusters = [to_b64(st_dir / f"thruster_f{i}.png") for i in range(4)]
sparks = [to_b64(st_dir / f"hit_spark_f{i}.png") for i in range(3)]
drone_b64 = to_b64(sp_dir / "drone_f0.png")
escort_b64 = to_b64(sp_dir / "escort_f0.png")
boss_b64 = to_b64(sp_dir / "boss_f0.png")

html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
  <style>
    canvas {{
      image-rendering: pixelated;
      image-rendering: crisp-edges;
    }}
  </style>
</head>
<body class="bg-transparent text-[var(--foreground)] antialiased p-3">
  <div class="bg-[var(--card)] text-[var(--foreground)] border border-[var(--border)] rounded-2xl p-5 shadow-lg max-w-4xl mx-auto">
    <!-- Header -->
    <div class="flex items-center justify-between border-b border-[var(--border)] pb-3 mb-4">
      <div>
        <h2 class="text-[var(--foreground)] font-bold text-lg flex items-center gap-2">
          <span class="inline-block w-3 h-3 rounded-full bg-cyan-400 animate-ping"></span>
          Steredenn VFX Interactive Hardware Simulator (720p 60Hz)
        </h2>
        <p class="text-[var(--muted-foreground)] text-xs mt-0.5">
          Mô phỏng trực tiếp logic hiển thị Color Mapper & Physics Engine chạy trên FPGA EBAZ4205
        </p>
      </div>
      <div class="flex items-center gap-2">
        <span class="text-xs px-2.5 py-1 rounded-full bg-cyan-500/10 text-cyan-400 font-mono border border-cyan-500/30">
          60 FPS HDMI
        </span>
        <span class="text-xs px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-400 font-mono border border-emerald-500/30">
          WNS: +0.334ns
        </span>
      </div>
    </div>

    <!-- Canvas Container -->
    <div class="relative rounded-xl overflow-hidden border border-[var(--border)] bg-[#05040a] flex justify-center items-center shadow-inner">
      <canvas id="gameCanvas" width="640" height="360" class="w-full max-w-[640px] h-[360px] block cursor-crosshair"></canvas>
      <div id="flashOverlay" class="absolute inset-0 bg-white opacity-0 pointer-events-none transition-opacity duration-75"></div>
    </div>

    <!-- Interactive Control Deck -->
    <div class="mt-4 grid grid-cols-2 md:grid-cols-4 gap-2.5">
      <button id="btnFire" class="px-3.5 py-2 rounded-xl bg-cyan-600/20 hover:bg-cyan-600/30 text-cyan-300 border border-cyan-500/40 text-xs font-semibold flex items-center justify-center gap-1.5 transition active:scale-95">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
        Bắn Đạn (Muzzle Flash)
      </button>

      <button id="btnExplode" class="px-3.5 py-2 rounded-xl bg-rose-600/20 hover:bg-rose-600/30 text-rose-300 border border-rose-500/40 text-xs font-semibold flex items-center justify-center gap-1.5 transition active:scale-95">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
        Nổ Quái + Lens Flare
      </button>

      <button id="btnShake" class="px-3.5 py-2 rounded-xl bg-amber-600/20 hover:bg-amber-600/30 text-amber-300 border border-amber-500/40 text-xs font-semibold flex items-center justify-center gap-1.5 transition active:scale-95">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/></svg>
        Rung Màn Hình (Shake)
      </button>

      <button id="btnTilt" class="px-3.5 py-2 rounded-xl bg-purple-600/20 hover:bg-purple-600/30 text-purple-300 border border-purple-500/40 text-xs font-semibold flex items-center justify-center gap-1.5 transition active:scale-95">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"/></svg>
        Lượn Tàu (Banking Roll)
      </button>
    </div>

    <!-- Active Effects Legend -->
    <div class="mt-4 pt-3 border-t border-[var(--border)] flex flex-wrap items-center justify-between text-xs text-[var(--muted-foreground)]">
      <div class="flex items-center gap-4">
        <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-cyan-400"></span> Muzzle Flash & Laser Trail</span>
        <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-amber-400"></span> Hit Sparks (3 frames)</span>
        <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-rose-400"></span> 16-Frame Chunky Smoke</span>
        <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-purple-400"></span> Ghost Trail</span>
      </div>
      <div class="text-[var(--foreground)] font-mono text-xs">
        Bấm phím A/D: Lượn tàu | SPACE: Bắn
      </div>
    </div>
  </div>

  <script>
    const canvas = document.getElementById('gameCanvas');
    const ctx = canvas.getContext('2d');
    const flashEl = document.getElementById('flashOverlay');

    // Sprite Data URIs
    const expUrls = {exp_frames};
    const shipUrls = {ship_banks};
    const thrustUrls = {thrusters};
    const sparkUrls = {sparks};

    function loadImg(src) {{
      const img = new Image();
      img.src = src;
      return img;
    }}

    const expImgs = expUrls.map(loadImg);
    const shipImgs = shipUrls.map(loadImg);
    const thrustImgs = thrustUrls.map(loadImg);
    const sparkImgs = sparkUrls.map(loadImg);
    const droneImg = loadImg('{drone_b64}');
    const escortImg = loadImg('{escort_b64}');
    const bossImg = loadImg('{boss_b64}');

    // State Variables
    let frame = 0;
    let shipX = 300, shipY = 295;
    let shipTilt = 2; // 0..4 (2 = straight)
    let tiltTarget = 2;
    let muzzleTimer = 0;
    let screenShakeTimer = 0;
    let hitStopTimer = 0;

    let lasers = [];
    let explosions = [];
    let sparksList = [];
    let asteroids = [
      {{ x: 120, y: 80, vx: -0.4, vy: 0.8, r: 14 }},
      {{ x: 500, y: 220, vx: 0.3, vy: 1.2, r: 10 }}
    ];

    // Starfield Parallax
    const stars = [];
    for (let i = 0; i < 70; i++) {{
      stars.push({{
        x: Math.random() * 640,
        y: Math.random() * 360,
        speed: 0.5 + Math.random() * 2.5,
        color: ['#ffffff', '#00e5ff', '#ff5577', '#ffee44', '#8888ff'][Math.floor(Math.random() * 5)]
      }});
    }}

    function fireLaser() {{
      muzzleTimer = 4;
      lasers.push({{ x: shipX + 5, y: shipY - 10, vy: 12 }});
      lasers.push({{ x: shipX + 21, y: shipY - 10, vy: 12 }});
    }}

    function triggerExplosion(x, y) {{
      screenShakeTimer = 10;
      explosions.push({{ x: x - 16, y: y - 16, frame: 0, timer: 0 }});
      sparksList.push({{ x: x + 4, y: y + 4, frame: 0, timer: 0 }});
      flashEl.style.opacity = '0.35';
      setTimeout(() => {{ flashEl.style.opacity = '0'; }}, 80);
    }}

    // Button event listeners
    document.getElementById('btnFire').addEventListener('click', fireLaser);
    document.getElementById('btnExplode').addEventListener('click', () => {{
      triggerExplosion(260 + Math.random() * 120, 100 + Math.random() * 80);
    }});
    document.getElementById('btnShake').addEventListener('click', () => {{
      screenShakeTimer = 12;
    }});
    document.getElementById('btnTilt').addEventListener('click', () => {{
      tiltTarget = (tiltTarget === 4) ? 0 : 4;
    }});

    window.addEventListener('keydown', (e) => {{
      if (e.key === ' ' || e.code === 'Space') {{ fireLaser(); e.preventDefault(); }}
      if (e.key === 'a' || e.key === 'ArrowLeft') {{ tiltTarget = 0; shipX = Math.max(40, shipX - 8); }}
      if (e.key === 'd' || e.key === 'ArrowRight') {{ tiltTarget = 4; shipX = Math.min(580, shipX + 8); }}
    }});
    window.addEventListener('keyup', (e) => {{
      if (['a', 'd', 'ArrowLeft', 'ArrowRight'].includes(e.key)) {{ tiltTarget = 2; }}
    }});

    // Auto action timeline loop
    setInterval(() => {{
      if (frame % 80 === 0) fireLaser();
      if (frame % 160 === 40) triggerExplosion(360, 120);
    }}, 16);

    // Main 60FPS Game Loop
    function update() {{
      frame++;

      // Tilt smoothing
      if (shipTilt < tiltTarget) shipTilt++;
      else if (shipTilt > tiltTarget) shipTilt--;

      // Update screen shake offsets
      let sx = 0, sy = 0;
      if (screenShakeTimer > 0) {{
        screenShakeTimer--;
        sx = (Math.random() - 0.5) * 8;
        sy = (Math.random() - 0.5) * 6;
      }}

      // Clear & Background
      ctx.fillStyle = '#06050e';
      ctx.fillRect(0, 0, 640, 360);

      // Starfield
      for (const s of stars) {{
        s.y += s.speed;
        if (s.y > 360) s.y = 32;
        ctx.fillStyle = s.color;
        ctx.fillRect(s.x, s.y, s.speed > 2 ? 2 : 1, s.speed > 2 ? 2 : 1);
      }}

      // Asteroid Field
      for (const ast of asteroids) {{
        ast.x += ast.vx;
        ast.y += ast.vy;
        if (ast.y > 370) {{ ast.y = 35; ast.x = Math.random() * 600; }}
        if (ast.x < -20) ast.x = 650;

        ctx.save();
        ctx.translate(ast.x + sx, ast.y + sy);
        // Chunky rock
        ctx.fillStyle = '#564a40';
        ctx.beginPath();
        ctx.arc(0, 0, ast.r, 0, Math.PI * 2);
        ctx.fill();
        // Highlight rim
        ctx.strokeStyle = '#8e8074';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(0, 0, ast.r, Math.PI * 0.8, Math.PI * 1.8);
        ctx.stroke();
        // Crater
        ctx.fillStyle = '#221915';
        ctx.beginPath();
        ctx.arc(-2, -1, ast.r * 0.35, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }}

      // Fleet
      const fleetBaseX = 200 + Math.sin(frame * 0.03) * 20;
      for (let c = 0; c < 4; c++) {{
        const cx = fleetBaseX + c * 70 + sx;
        ctx.drawImage(bossImg, cx, 50 + sy, 26, 26);
        ctx.drawImage(escortImg, cx, 80 + sy, 26, 26);
        ctx.drawImage(droneImg, cx, 110 + sy, 26, 26);
        ctx.drawImage(droneImg, cx, 140 + sy, 26, 26);
      }}

      // Ghost trail for diving escort
      const diveY = 120 + ((frame * 3) % 240);
      const diveX = 340 + Math.sin(diveY * 0.05) * 40 + sx;
      if (diveY < 320) {{
        ctx.fillStyle = 'rgba(42, 16, 64, 0.6)';
        ctx.fillRect(diveX - 4, diveY - 14 + sy, 24, 24);
        ctx.drawImage(escortImg, diveX, diveY + sy, 24, 24);
      }}

      // Update & Draw Lasers (Motion blur stretch)
      for (let i = lasers.length - 1; i >= 0; i--) {{
        const l = lasers[i];
        l.y -= l.vy;
        if (l.y < 32) {{
          lasers.splice(i, 1);
          continue;
        }}
        // Cyan & White Motion blur
        const grad = ctx.createLinearGradient(0, l.y + sy, 0, l.y + 20 + sy);
        grad.addColorStop(0, '#ffffff');
        grad.addColorStop(0.3, '#00ffff');
        grad.addColorStop(1, 'rgba(0, 102, 204, 0.1)');
        ctx.fillStyle = grad;
        ctx.fillRect(l.x + sx, l.y + sy, 3, 20);

        // Check collision with fleet
        if (l.y < 155 && l.y > 130 && Math.abs(l.x - (fleetBaseX + 140)) < 30) {{
          triggerExplosion(l.x, l.y);
          lasers.splice(i, 1);
        }}
      }}

      // Explosions (16 frames)
      for (let i = explosions.length - 1; i >= 0; i--) {{
        const exp = explosions[i];
        exp.timer++;
        if (exp.timer >= 2) {{
          exp.timer = 0;
          exp.frame++;
        }}
        if (exp.frame < 16) {{
          if (expImgs[exp.frame] && expImgs[exp.frame].complete) {{
            ctx.drawImage(expImgs[exp.frame], exp.x + sx, exp.y + sy, 48, 48);
          }}
          // Anamorphic Lens Flare during frames 0..3
          if (exp.frame <= 3) {{
            ctx.fillStyle = 'rgba(160, 255, 255, 0.7)';
            ctx.fillRect(0, exp.y + 24 + sy, 640, 2);
            ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
            ctx.fillRect(exp.x + 10 + sx, exp.y + 23 + sy, 28, 4);
          }}
        }} else {{
          explosions.splice(i, 1);
        }}
      }}

      // Hit Sparks (3 frames)
      for (let i = sparksList.length - 1; i >= 0; i--) {{
        const sp = sparksList[i];
        sp.timer++;
        if (sp.timer >= 3) {{
          sp.timer = 0;
          sp.frame++;
        }}
        if (sp.frame < 3) {{
          if (sparkImgs[sp.frame] && sparkImgs[sp.frame].complete) {{
            ctx.drawImage(sparkImgs[sp.frame], sp.x + sx, sp.y + sy, 16, 16);
          }}
        }} else {{
          sparksList.splice(i, 1);
        }}
      }}

      // Player Ship & Modular Thruster
      const curShip = shipImgs[shipTilt];
      if (curShip && curShip.complete) {{
        ctx.drawImage(curShip, shipX + sx, shipY + sy, 28, 28);
      }}

      // Thruster
      const thrustIdx = Math.floor(frame / 2) % 4;
      const curThrust = thrustImgs[thrustIdx];
      const thrustOffset = (shipTilt === 0) ? 9 : (shipTilt === 1 ? 8 : (shipTilt === 3 ? 6 : (shipTilt === 4 ? 5 : 7)));
      if (curThrust && curThrust.complete) {{
        ctx.drawImage(curThrust, shipX + thrustOffset + sx, shipY + 24 + sy, 14, 14);
      }}

      // Muzzle Flash
      if (muzzleTimer > 0) {{
        muzzleTimer--;
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(shipX + 3 + sx, shipY - 4 + sy, 4, 4);
        ctx.fillRect(shipX + 20 + sx, shipY - 4 + sy, 4, 4);
      }}

      // Top HUD (Rock Solid, Zero Shake)
      ctx.fillStyle = 'rgba(0, 0, 0, 0.85)';
      ctx.fillRect(0, 0, 640, 28);
      ctx.font = '10px monospace';
      ctx.fillStyle = '#ff4444';
      ctx.fillText('1UP  012480', 25, 18);
      ctx.fillStyle = '#00ffff';
      ctx.fillText('HIGH SCORE  050000', 260, 18);
      ctx.fillStyle = '#ffff44';
      ctx.fillText('STAGE 03', 530, 18);

      requestAnimationFrame(update);
    }}

    requestAnimationFrame(update);
  </script>
</body>
</html>
"""

out_html = Path(r"C:\Users\thanh\.gemini\antigravity\brain\58b47c13-6381-4da7-810e-6c0c0feae7de\steredenn_vfx_player.html")
out_html.write_text(html_content, encoding="utf-8")
print(f"HTML Player generated: {out_html}")

