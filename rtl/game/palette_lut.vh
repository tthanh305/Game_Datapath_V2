// 16-Color Master Palette LUT (Supports both RGB444 12-bit VGA and RGB888 24-bit HDMI)
function automatic [11:0] get_rgb444(input [3:0] idx, input hit_flash);
  if (idx == 4'h0) get_rgb444 = 12'h000;
  else if (hit_flash) get_rgb444 = 12'hFFF; // Instant 0.08s White Hit-Flash in 1 LUT!
  else case (idx)
    4'h0: get_rgb444 = 12'h000; // TRANSPARENT
    4'h1: get_rgb444 = 12'h112; // DEEP_SPACE
    4'h2: get_rgb444 = 12'h234; // DARK_HULL
    4'h3: get_rgb444 = 12'h678; // STEEL_GREY
    4'h4: get_rgb444 = 12'hFFF; // PURE_WHITE
    4'h5: get_rgb444 = 12'h3EF; // CYAN_NEON
    4'h6: get_rgb444 = 12'h27F; // BLUE_ENERGY
    4'h7: get_rgb444 = 12'hB4F; // PURPLE_SHLD
    4'h8: get_rgb444 = 12'hF5A; // PINK_ORB
    4'h9: get_rgb444 = 12'hF32; // RED_CRIMSON
    4'hA: get_rgb444 = 12'hF92; // ORANGE_FIRE
    4'hB: get_rgb444 = 12'hFE6; // YELLOW_GOLD
    4'hC: get_rgb444 = 12'h4FC; // TEAL_MINT
    4'hD: get_rgb444 = 12'h221; // NEBULA_DARK
    4'hE: get_rgb444 = 12'h452; // NEBULA_MID
    4'hF: get_rgb444 = 12'h873; // NEBULA_GOLD
    default: get_rgb444 = 12'h000;
  endcase
endfunction

function automatic [23:0] get_rgb888(input [3:0] idx, input hit_flash);
  reg [11:0] c;
  begin
    c = get_rgb444(idx, hit_flash);
    get_rgb888 = {c[11:8], c[11:8], c[7:4], c[7:4], c[3:0], c[3:0]};
  end
endfunction
