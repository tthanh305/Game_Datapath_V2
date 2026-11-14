// Pipelined menu renderer used by game_video. Preserves exact 1-PCK latency
// and startup button border colors at (430,350) and (610,350).
module game_menu_renderer_timed (
    input wire clk,
    input wire rst,
    input wire active,
    input wire [1:0] selected_option,
    input wire [10:0] x,
    input wire [10:0] y,
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);

localparam [23:0] BG       = 24'h03070B;
localparam [23:0] GRID     = 24'h071018;
localparam [23:0] WHITE    = 24'hF4F7FA;
localparam [23:0] YELLOW   = 24'hFFD166;
localparam [23:0] ORANGE   = 24'hFF8822;
localparam [23:0] DIM      = 24'h587080;
localparam [23:0] BUTTON   = 24'h050B12;
localparam [23:0] BTN_SEL  = 24'h0A1929;
localparam [23:0] BORDER   = 24'h172532;
localparam [23:0] CYAN2    = 24'h55E6FF;

function [7:0] decode_cell;
    input [7:0] sx;
    reg [7:0] result;
    begin
        result = 8'd0;
        if      (sx < 8'd6)   begin result[7:3]=5'd0;  result[2:0]=sx[2:0]; end
        else if (sx < 8'd12)  begin result[7:3]=5'd1;  result[2:0]=sx-8'd6; end
        else if (sx < 8'd18)  begin result[7:3]=5'd2;  result[2:0]=sx-8'd12; end
        else if (sx < 8'd24)  begin result[7:3]=5'd3;  result[2:0]=sx-8'd18; end
        else if (sx < 8'd30)  begin result[7:3]=5'd4;  result[2:0]=sx-8'd24; end
        else if (sx < 8'd36)  begin result[7:3]=5'd5;  result[2:0]=sx-8'd30; end
        else if (sx < 8'd42)  begin result[7:3]=5'd6;  result[2:0]=sx-8'd36; end
        else if (sx < 8'd48)  begin result[7:3]=5'd7;  result[2:0]=sx-8'd42; end
        else if (sx < 8'd54)  begin result[7:3]=5'd8;  result[2:0]=sx-8'd48; end
        else if (sx < 8'd60)  begin result[7:3]=5'd9;  result[2:0]=sx-8'd54; end
        else if (sx < 8'd66)  begin result[7:3]=5'd10; result[2:0]=sx-8'd60; end
        else if (sx < 8'd72)  begin result[7:3]=5'd11; result[2:0]=sx-8'd66; end
        else if (sx < 8'd78)  begin result[7:3]=5'd12; result[2:0]=sx-8'd72; end
        else if (sx < 8'd84)  begin result[7:3]=5'd13; result[2:0]=sx-8'd78; end
        else if (sx < 8'd90)  begin result[7:3]=5'd14; result[2:0]=sx-8'd84; end
        else if (sx < 8'd96)  begin result[7:3]=5'd15; result[2:0]=sx-8'd90; end
        else if (sx < 8'd102) begin result[7:3]=5'd16; result[2:0]=sx-8'd96; end
        else if (sx < 8'd108) begin result[7:3]=5'd17; result[2:0]=sx-8'd102; end
        else if (sx < 8'd114) begin result[7:3]=5'd18; result[2:0]=sx-8'd108; end
        else if (sx < 8'd120) begin result[7:3]=5'd19; result[2:0]=sx-8'd114; end
        else if (sx < 8'd126) begin result[7:3]=5'd20; result[2:0]=sx-8'd120; end
        else if (sx < 8'd132) begin result[7:3]=5'd21; result[2:0]=sx-8'd126; end
        else                  begin result[7:3]=5'd22; result[2:0]=sx-8'd132; end
        decode_cell = result;
    end
endfunction

wire [10:0] lookahead_x = x + 11'd1;
reg [2:0] text_mode;
reg [10:0] text_x0, text_y0;
reg [1:0] text_scale_shift;
reg [7:0] scaled_x;
reg [2:0] scaled_y;
wire [7:0] decoded_cell = decode_cell(scaled_x);
wire [4:0] character_index = decoded_cell[7:3];
wire [2:0] character_column = decoded_cell[2:0];
reg [7:0] character;
reg inside_button, button_border, selected_button, button_glow;
reg [23:0] stage1_color;
reg [23:0] stage2_color;
reg active_q;
reg [2:0] text_mode_q;
reg [2:0] character_column_q;
reg [2:0] scaled_y_q;
reg [7:0] character_q;
reg selected_button_q;
reg [23:0] stage1_color_q;
wire [4:0] glyph_pixels;
wire text_pixel_q = (text_mode_q != 3'd0) &&
                    (character_column_q < 3'd5) &&
                    glyph_pixels[4-character_column_q];

// Procedural decorative ship emblem above title (centered at X=640, Y=82..132)
wire [10:0] emb_dx = (lookahead_x >= 11'd640) ? (lookahead_x - 11'd640) : (11'd640 - lookahead_x);
wire [10:0] emb_dy = y - 11'd82;
wire in_emblem_ship  = (y >= 11'd82 && y < 11'd122) && (emb_dx <= (emb_dy >> 1) + 11'd2);
wire in_emblem_core  = (y >= 11'd92 && y < 11'd110) && (emb_dx <= 11'd4);
wire in_emblem_wing  = (y >= 11'd104 && y < 11'd120) && (emb_dx >= 11'd6 && emb_dx <= (emb_dy >> 1) + 11'd2);
wire in_emblem_flame = (y >= 11'd122 && y < 11'd132) && (emb_dx >= 11'd2 && emb_dx <= 11'd5);

wire [9:0] star_hash = lookahead_x[9:0] ^ {y[4:0], y[9:5]} ^ {y[1:0], y[9:2]};
wire menu_star_bright = (star_hash == 10'h2A5);
wire menu_star_dim    = (star_hash == 10'h17C);

font_rom menu_font (
    .char_code(character_q), .row(scaled_y_q), .pixels(glyph_pixels)
);

always @* begin
    text_mode = 3'd0;
    text_x0 = 0;
    text_y0 = 0;
    text_scale_shift = 0;
    scaled_x = 0;
    scaled_y = 0;
    character = " ";

    if (active && lookahead_x >= 11'd520 && lookahead_x < 11'd760 &&
        y >= 11'd150 && y < 11'd178) begin
        text_mode = 3'd1; text_x0 = 11'd520; text_y0 = 11'd150; text_scale_shift = 2'd2;
    end else if (active && lookahead_x >= 11'd455 && lookahead_x < 11'd551 &&
                 y >= 11'd374 && y < 11'd388) begin
        text_mode = 3'd2; text_x0 = 11'd455; text_y0 = 11'd374; text_scale_shift = 2'd1;
    end else if (active && lookahead_x >= 11'd649 && lookahead_x < 11'd721 &&
                 y >= 11'd374 && y < 11'd388) begin
        text_mode = 3'd3; text_x0 = 11'd649; text_y0 = 11'd374; text_scale_shift = 2'd1;
    end else if (active && lookahead_x >= 11'd809 && lookahead_x < 11'd941 &&
                 y >= 11'd374 && y < 11'd388) begin
        text_mode = 3'd4; text_x0 = 11'd809; text_y0 = 11'd374; text_scale_shift = 2'd1;
    end else if (active && lookahead_x >= 11'd532 && lookahead_x < 11'd748 &&
                 y >= 11'd480 && y < 11'd494) begin
        text_mode = 3'd5; text_x0 = 11'd532; text_y0 = 11'd480; text_scale_shift = 2'd1;
    end else if (active && lookahead_x >= 11'd508 && lookahead_x < 11'd772 &&
                 y >= 11'd504 && y < 11'd518) begin
        text_mode = 3'd6; text_x0 = 11'd508; text_y0 = 11'd504; text_scale_shift = 2'd1;
    end

    if (text_scale_shift == 2'd2) begin
        scaled_x = (lookahead_x - text_x0) >> 2;
        scaled_y = (y - text_y0) >> 2;
    end else if (text_scale_shift == 2'd1) begin
        scaled_x = (lookahead_x - text_x0) >> 1;
        scaled_y = (y - text_y0) >> 1;
    end

    case (text_mode)
        3'd1: case (character_index)
            0: character="F"; 1: character="L"; 2: character="Y";
            4: character="H"; 5: character="U"; 6: character="N";
            7: character="T"; 8: character="E"; 9: character="R";
            default: character=" ";
        endcase
        3'd2: case (character_index)
            0: character="N"; 1: character="E"; 2: character="W";
            4: character="G"; 5: character="A"; 6: character="M"; 7: character="E";
            default: character=" ";
        endcase
        3'd3: case (character_index)
            0: character="R"; 1: character="E"; 2: character="S";
            3: character="U"; 4: character="M"; 5: character="E";
            default: character=" ";
        endcase
        3'd4: case (character_index)
            0: character="S"; 1: character="C"; 2: character="O";
            3: character="R"; 4: character="E"; 6: character="B";
            7: character="O"; 8: character="A"; 9: character="R"; 10: character="D";
            default: character=" ";
        endcase
        3'd5: case (character_index) // "K2/K5 MOVE SHIP"
            0: character="K"; 1: character="2"; 2: character="/";
            3: character="K"; 4: character="5"; 5: character=" ";
            6: character="M"; 7: character="O"; 8: character="V"; 9: character="E";
            10: character=" "; 11: character="S"; 12: character="H"; 13: character="I"; 14: character="P";
            default: character=" ";
        endcase
        3'd6: case (character_index) // "TAP K3:LASER HOLD:PAUSE"
            0: character="T"; 1: character="A"; 2: character="P"; 3: character=" ";
            4: character="K"; 5: character="3"; 6: character=":"; 7: character="L";
            8: character="A"; 9: character="S"; 10: character="E"; 11: character="R";
            12: character=" "; 13: character="H"; 14: character="O"; 15: character="L";
            16: character="D"; 17: character=":"; 18: character="P"; 19: character="A";
            20: character="U"; 21: character="S"; 22: character="E";
            default: character=" ";
        endcase
        default: character=" ";
    endcase

    stage1_color = BG;
    inside_button = 1'b0;
    button_border = 1'b0;
    selected_button = 1'b0;
    button_glow = 1'b0;
    if (active) begin
        if ((lookahead_x[4:0] == 0) || (y[4:0] == 0))
            stage1_color = GRID;
        else if (menu_star_bright)
            stage1_color = CYAN2;
        else if (menu_star_dim)
            stage1_color = DIM;

        // Decorative Title Frame & Ship Emblem
        if (y >= 11'd136 && y <= 11'd192 && lookahead_x >= 11'd480 && lookahead_x <= 11'd800) begin
            if (y == 11'd136 || y == 11'd192 || lookahead_x == 11'd480 || lookahead_x == 11'd800)
                stage1_color = 24'h1E3A5F;
            else if (y == 11'd138 || y == 11'd190)
                stage1_color = 24'h0E2238;
        end
        if (in_emblem_flame)
            stage1_color = (y < 11'd127) ? YELLOW : ORANGE;
        else if (in_emblem_core)
            stage1_color = CYAN2;
        else if (in_emblem_wing)
            stage1_color = (emb_dx[1:0] == 2'b00) ? CYAN2 : 24'h446688;
        else if (in_emblem_ship)
            stage1_color = WHITE;

        if (lookahead_x >= 11'd430 && lookahead_x < 11'd580 &&
            y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (lookahead_x == 11'd430) || (lookahead_x == 11'd579) ||
                            (y == 11'd350) || (y == 11'd404);
            button_glow   = (lookahead_x == 11'd431) || (lookahead_x == 11'd578) ||
                            (y == 11'd351) || (y == 11'd403);
            selected_button = (selected_option == 2'd0);
        end else if (lookahead_x >= 11'd610 && lookahead_x < 11'd760 &&
                     y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (lookahead_x == 11'd610) || (lookahead_x == 11'd759) ||
                            (y == 11'd350) || (y == 11'd404);
            button_glow   = (lookahead_x == 11'd611) || (lookahead_x == 11'd758) ||
                            (y == 11'd351) || (y == 11'd403);
            selected_button = (selected_option == 2'd1);
        end else if (lookahead_x >= 11'd790 && lookahead_x < 11'd970 &&
                     y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (lookahead_x == 11'd790) || (lookahead_x == 11'd969) ||
                            (y == 11'd350) || (y == 11'd404);
            button_glow   = (lookahead_x == 11'd791) || (lookahead_x == 11'd968) ||
                            (y == 11'd351) || (y == 11'd403);
            selected_button = (selected_option == 2'd2);
        end
        if (inside_button) stage1_color = selected_button ? BTN_SEL : BUTTON;
        if (button_glow && selected_button) stage1_color = 24'h1E6091;
        if (button_border) stage1_color = selected_button ? CYAN2 : BORDER;
        if (y == 11'd455 && lookahead_x >= 11'd430 && lookahead_x < 11'd970)
            stage1_color = DIM;
        if (y == 11'd457 && lookahead_x >= 11'd520 && lookahead_x < 11'd880)
            stage1_color = 24'h22384A;
    end
end

always @(posedge clk) begin
    if (rst) begin
        active_q <= 1'b0;
        text_mode_q <= 3'd0;
        character_column_q <= 3'd0;
        scaled_y_q <= 3'd0;
        character_q <= " ";
        selected_button_q <= 1'b0;
        stage1_color_q <= BG;
    end else begin
        active_q <= active;
        text_mode_q <= text_mode;
        character_column_q <= character_column;
        scaled_y_q <= scaled_y;
        character_q <= character;
        selected_button_q <= selected_button;
        stage1_color_q <= stage1_color;
    end
end

always @* begin
    stage2_color = stage1_color_q;
    if (active_q && text_pixel_q) begin
        if (text_mode_q == 3'd1)
            stage2_color = (scaled_y_q <= 3'd1) ? 24'hFFFFAA : (scaled_y_q <= 3'd4) ? YELLOW : ORANGE;
        else if (text_mode_q == 3'd5 || text_mode_q == 3'd6)
            stage2_color = 24'h789AB0;
        else
            stage2_color = selected_button_q ? CYAN2 : WHITE;
    end
    red = stage2_color[23:16];
    green = stage2_color[15:8];
    blue = stage2_color[7:0];
end

endmodule
