module game_menu_renderer (
    input wire active,
    input wire [1:0] selected_option,
    input wire [10:0] x,
    input wire [10:0] y,
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);

localparam [23:0] BG = 24'h03070B;
localparam [23:0] GRID = 24'h071018;
localparam [23:0] WHITE = 24'hF4F7FA;
localparam [23:0] YELLOW = 24'hFFD166;
localparam [23:0] DIM = 24'h587080;
localparam [23:0] BUTTON = 24'h050B12;
localparam [23:0] BORDER = 24'h172532;
localparam [23:0] CYAN2 = 24'h55E6FF;

// Decode a scaled 5x7 font cell. The menu uses 2x text, except for
// the 4x title. This shared decoder replaces synthesized divide/modulo
// operators in four independently expanded text-drawing tasks.
function [6:0] decode_cell;
    input [6:0] sx;
    reg [6:0] result;
    begin
        result = 7'd0;
        if      (sx < 7'd6)  begin result[6:3]=4'd0;  result[2:0]=sx[2:0]; end
        else if (sx < 7'd12) begin result[6:3]=4'd1;  result[2:0]=sx-7'd6; end
        else if (sx < 7'd18) begin result[6:3]=4'd2;  result[2:0]=sx-7'd12; end
        else if (sx < 7'd24) begin result[6:3]=4'd3;  result[2:0]=sx-7'd18; end
        else if (sx < 7'd30) begin result[6:3]=4'd4;  result[2:0]=sx-7'd24; end
        else if (sx < 7'd36) begin result[6:3]=4'd5;  result[2:0]=sx-7'd30; end
        else if (sx < 7'd42) begin result[6:3]=4'd6;  result[2:0]=sx-7'd36; end
        else if (sx < 7'd48) begin result[6:3]=4'd7;  result[2:0]=sx-7'd42; end
        else if (sx < 7'd54) begin result[6:3]=4'd8;  result[2:0]=sx-7'd48; end
        else if (sx < 7'd60) begin result[6:3]=4'd9;  result[2:0]=sx-7'd54; end
        else                 begin result[6:3]=4'd10; result[2:0]=sx-7'd60; end
        decode_cell = result;
    end
endfunction

reg [2:0] text_mode;
reg [10:0] text_x0, text_y0;
reg [1:0] text_scale_shift;
reg [6:0] scaled_x;
reg [2:0] scaled_y;
wire [6:0] decoded_cell = decode_cell(scaled_x);
wire [3:0] character_index = decoded_cell[6:3];
wire [2:0] character_column = decoded_cell[2:0];
reg [7:0] character;
wire [4:0] glyph_pixels;
font_rom menu_font (.char_code(character), .row(scaled_y), .pixels(glyph_pixels));
wire text_pixel = (text_mode != 3'd0) && (character_column < 3'd5) &&
                  glyph_pixels[4-character_column];

reg inside_button, button_border, selected_button;
reg [23:0] color;

always @* begin
    text_mode = 3'd0;
    text_x0 = 0;
    text_y0 = 0;
    text_scale_shift = 0;
    scaled_x = 0;
    scaled_y = 0;
    character = " ";

    // One shared text-coordinate/font path for title and all three labels.
    if (active && x >= 11'd520 && x < 11'd760 && y >= 11'd150 && y < 11'd178) begin
        text_mode = 3'd1; text_x0 = 11'd520; text_y0 = 11'd150; text_scale_shift = 2'd2;
    end else if (active && x >= 11'd455 && x < 11'd551 && y >= 11'd374 && y < 11'd388) begin
        text_mode = 3'd2; text_x0 = 11'd455; text_y0 = 11'd374; text_scale_shift = 2'd1;
    end else if (active && x >= 11'd649 && x < 11'd721 && y >= 11'd374 && y < 11'd388) begin
        text_mode = 3'd3; text_x0 = 11'd649; text_y0 = 11'd374; text_scale_shift = 2'd1;
    end else if (active && x >= 11'd809 && x < 11'd941 && y >= 11'd374 && y < 11'd388) begin
        text_mode = 3'd4; text_x0 = 11'd809; text_y0 = 11'd374; text_scale_shift = 2'd1;
    end

    if (text_scale_shift == 2'd2) begin
        scaled_x = (x - text_x0) >> 2;
        scaled_y = (y - text_y0) >> 2;
    end else if (text_scale_shift == 2'd1) begin
        scaled_x = (x - text_x0) >> 1;
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
        default: character=" ";
    endcase
end

always @* begin
    color = BG;
    inside_button = 1'b0;
    button_border = 1'b0;
    selected_button = 1'b0;

    if (active) begin
        // Power-of-two grid tests map directly to coordinate bits.
        if ((x[4:0] == 0) || (y[4:0] == 0))
            color = GRID;

        if (x >= 11'd430 && x < 11'd580 && y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (x == 11'd430) || (x == 11'd579) || (y == 11'd350) || (y == 11'd404);
            selected_button = (selected_option == 2'd0);
        end else if (x >= 11'd610 && x < 11'd760 && y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (x == 11'd610) || (x == 11'd759) || (y == 11'd350) || (y == 11'd404);
            selected_button = (selected_option == 2'd1);
        end else if (x >= 11'd790 && x < 11'd970 && y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (x == 11'd790) || (x == 11'd969) || (y == 11'd350) || (y == 11'd404);
            selected_button = (selected_option == 2'd2);
        end

        if (inside_button) color = BUTTON;
        if (button_border) color = selected_button ? CYAN2 : BORDER;
        if (text_pixel) color = (text_mode == 3'd1) ? YELLOW : WHITE;
        if (y == 11'd455 && x >= 11'd470 && x < 11'd810) color = DIM;
    end

    red = color[23:16];
    green = color[15:8];
    blue = color[7:0];
end

endmodule

// Pipelined menu renderer used by game_video. Stage 1 prepares the coordinate,
// character/font address and button/background style. Stage 2 performs the
// font lookup and final color selection. Looking one pixel ahead preserves the
// existing one-PCK RGB latency at game_video's output register.
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

localparam [23:0] BG = 24'h03070B;
localparam [23:0] GRID = 24'h071018;
localparam [23:0] WHITE = 24'hF4F7FA;
localparam [23:0] YELLOW = 24'hFFD166;
localparam [23:0] DIM = 24'h587080;
localparam [23:0] BUTTON = 24'h050B12;
localparam [23:0] BORDER = 24'h172532;
localparam [23:0] CYAN2 = 24'h55E6FF;

function [6:0] decode_cell;
    input [6:0] sx;
    reg [6:0] result;
    begin
        result = 7'd0;
        if      (sx < 7'd6)  begin result[6:3]=4'd0;  result[2:0]=sx[2:0]; end
        else if (sx < 7'd12) begin result[6:3]=4'd1;  result[2:0]=sx-7'd6; end
        else if (sx < 7'd18) begin result[6:3]=4'd2;  result[2:0]=sx-7'd12; end
        else if (sx < 7'd24) begin result[6:3]=4'd3;  result[2:0]=sx-7'd18; end
        else if (sx < 7'd30) begin result[6:3]=4'd4;  result[2:0]=sx-7'd24; end
        else if (sx < 7'd36) begin result[6:3]=4'd5;  result[2:0]=sx-7'd30; end
        else if (sx < 7'd42) begin result[6:3]=4'd6;  result[2:0]=sx-7'd36; end
        else if (sx < 7'd48) begin result[6:3]=4'd7;  result[2:0]=sx-7'd42; end
        else if (sx < 7'd54) begin result[6:3]=4'd8;  result[2:0]=sx-7'd48; end
        else if (sx < 7'd60) begin result[6:3]=4'd9;  result[2:0]=sx-7'd54; end
        else                 begin result[6:3]=4'd10; result[2:0]=sx-7'd60; end
        decode_cell = result;
    end
endfunction

wire [10:0] lookahead_x = x + 11'd1;
reg [2:0] text_mode;
reg [10:0] text_x0, text_y0;
reg [1:0] text_scale_shift;
reg [6:0] scaled_x;
reg [2:0] scaled_y;
wire [6:0] decoded_cell = decode_cell(scaled_x);
wire [3:0] character_index = decoded_cell[6:3];
wire [2:0] character_column = decoded_cell[2:0];
reg [7:0] character;
reg inside_button, button_border, selected_button;
reg [23:0] stage1_color;
reg [23:0] stage2_color;
reg active_q;
reg [2:0] text_mode_q;
reg [2:0] character_column_q;
reg [2:0] scaled_y_q;
reg [7:0] character_q;
reg [23:0] stage1_color_q;
wire [4:0] glyph_pixels;
wire text_pixel_q = (text_mode_q != 3'd0) &&
                    (character_column_q < 3'd5) &&
                    glyph_pixels[4-character_column_q];

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
        default: character=" ";
    endcase

    stage1_color = BG;
    inside_button = 1'b0;
    button_border = 1'b0;
    selected_button = 1'b0;
    if (active) begin
        if ((lookahead_x[4:0] == 0) || (y[4:0] == 0))
            stage1_color = GRID;
        if (lookahead_x >= 11'd430 && lookahead_x < 11'd580 &&
            y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (lookahead_x == 11'd430) || (lookahead_x == 11'd579) ||
                            (y == 11'd350) || (y == 11'd404);
            selected_button = (selected_option == 2'd0);
        end else if (lookahead_x >= 11'd610 && lookahead_x < 11'd760 &&
                     y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (lookahead_x == 11'd610) || (lookahead_x == 11'd759) ||
                            (y == 11'd350) || (y == 11'd404);
            selected_button = (selected_option == 2'd1);
        end else if (lookahead_x >= 11'd790 && lookahead_x < 11'd970 &&
                     y >= 11'd350 && y < 11'd405) begin
            inside_button = 1'b1;
            button_border = (lookahead_x == 11'd790) || (lookahead_x == 11'd969) ||
                            (y == 11'd350) || (y == 11'd404);
            selected_button = (selected_option == 2'd2);
        end
        if (inside_button) stage1_color = BUTTON;
        if (button_border) stage1_color = selected_button ? CYAN2 : BORDER;
        if (y == 11'd455 && lookahead_x >= 11'd470 && lookahead_x < 11'd810)
            stage1_color = DIM;
    end
end

always @(posedge clk) begin
    if (rst) begin
        active_q <= 1'b0;
        text_mode_q <= 3'd0;
        character_column_q <= 3'd0;
        scaled_y_q <= 3'd0;
        character_q <= " ";
        stage1_color_q <= BG;
    end else begin
        active_q <= active;
        text_mode_q <= text_mode;
        character_column_q <= character_column;
        scaled_y_q <= scaled_y;
        character_q <= character;
        stage1_color_q <= stage1_color;
    end
end

always @* begin
    stage2_color = stage1_color_q;
    if (active_q && text_pixel_q)
        stage2_color = (text_mode_q == 3'd1) ? YELLOW : WHITE;
    red = stage2_color[23:16];
    green = stage2_color[15:8];
    blue = stage2_color[7:0];
end

endmodule
