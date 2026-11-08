`timescale 1ns / 1ps
`include "game_params.vh"

// Combinational 5x7 font HUD for Top Score/Wave, Bottom Status Labels, and Win/Game Over Banners.
module game_hud (
    input wire [`GAME_COORD_WIDTH-1:0] pixel_x,
    input wire [`GAME_COORD_WIDTH-1:0] pixel_y,
    input wire [`GAME_SCORE_WIDTH-1:0] score,
    input wire win,
    input wire game_over,
    input wire [3:0] wave_num,
    input wire scoreboard_active,
    input wire [`GAME_SCORE_WIDTH-1:0] high_score_2,
    input wire [`GAME_SCORE_WIDTH-1:0] high_score_3,
    output reg pixel_on,
    output reg [23:0] color
);

function font_pixel;
    input [7:0] character;
    input [2:0] row;
    input [2:0] column;
    reg [34:0] glyph;
    reg [4:0] row_pixels;
    begin
        case (character)
            "0": glyph = {5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
            "1": glyph = {5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            "2": glyph = {5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
            "3": glyph = {5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
            "4": glyph = {5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
            "5": glyph = {5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
            "6": glyph = {5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
            "7": glyph = {5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
            "8": glyph = {5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
            "9": glyph = {5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
            "S": glyph = {5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
            "C": glyph = {5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
            "O": glyph = {5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            "R": glyph = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
            "E": glyph = {5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
            "W": glyph = {5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010};
            "I": glyph = {5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
            "N": glyph = {5'b10001,5'b11001,5'b11001,5'b10101,5'b10011,5'b10011,5'b10001};
            "G": glyph = {5'b01111,5'b10000,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110};
            "A": glyph = {5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            "M": glyph = {5'b10001,5'b11011,5'b10101,5'b10001,5'b10001,5'b10001,5'b10001};
            "V": glyph = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
            "H": glyph = {5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            "P": glyph = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
            "L": glyph = {5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
            "T": glyph = {5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
            "D": glyph = {5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
            default: glyph = 35'b0;
        endcase
        row_pixels = 5'b00000;
        case (row)
            3'd0: row_pixels = glyph[34:30];
            3'd1: row_pixels = glyph[29:25];
            3'd2: row_pixels = glyph[24:20];
            3'd3: row_pixels = glyph[19:15];
            3'd4: row_pixels = glyph[14:10];
            3'd5: row_pixels = glyph[9:5];
            3'd6: row_pixels = glyph[4:0];
            default: row_pixels = 5'b00000;
        endcase
        case (column)
            3'd0: font_pixel = row_pixels[4];
            3'd1: font_pixel = row_pixels[3];
            3'd2: font_pixel = row_pixels[2];
            3'd3: font_pixel = row_pixels[1];
            3'd4: font_pixel = row_pixels[0];
            default: font_pixel = 1'b0;
        endcase
    end
endfunction

reg [6:0] scaled_x;
reg [2:0] row_index, column_index;
reg [3:0] character_index;
reg [7:0] character;
reg [6:0] decoded_cell;

// Character-cell decoder supporting up to 11 cells; avoids synthesized division/modulo.
function [6:0] decode_cell;
    input [6:0] sx;
    begin
        if      (sx < 7'd6)   begin decode_cell[6:3] = 4'd0;  decode_cell[2:0] = sx;          end
        else if (sx < 7'd12)  begin decode_cell[6:3] = 4'd1;  decode_cell[2:0] = sx - 7'd6;   end
        else if (sx < 7'd18)  begin decode_cell[6:3] = 4'd2;  decode_cell[2:0] = sx - 7'd12;  end
        else if (sx < 7'd24)  begin decode_cell[6:3] = 4'd3;  decode_cell[2:0] = sx - 7'd18;  end
        else if (sx < 7'd30)  begin decode_cell[6:3] = 4'd4;  decode_cell[2:0] = sx - 7'd24;  end
        else if (sx < 7'd36)  begin decode_cell[6:3] = 4'd5;  decode_cell[2:0] = sx - 7'd30;  end
        else if (sx < 7'd42)  begin decode_cell[6:3] = 4'd6;  decode_cell[2:0] = sx - 7'd36;  end
        else if (sx < 7'd48)  begin decode_cell[6:3] = 4'd7;  decode_cell[2:0] = sx - 7'd42;  end
        else if (sx < 7'd54)  begin decode_cell[6:3] = 4'd8;  decode_cell[2:0] = sx - 7'd48;  end
        else if (sx < 7'd60)  begin decode_cell[6:3] = 4'd9;  decode_cell[2:0] = sx - 7'd54;  end
        else                  begin decode_cell[6:3] = 4'd10; decode_cell[2:0] = sx - 7'd60;  end
    end
endfunction

always @* begin
    pixel_on = 1'b0;
    color = 24'h000000;
    scaled_x = 7'd0;
    row_index = 3'd0;
    column_index = 3'd0;
    character_index = 4'd0;
    decoded_cell = 7'd0;
    character = " ";

    // 1. SCORE 00000. 3x/4x scaling at top-left (32, 16) to (296, 44).
    if (pixel_x >= 11'd32 && pixel_x < 11'd296 && pixel_y >= 11'd16 && pixel_y < 11'd44) begin
        scaled_x = (pixel_x - 11'd32) >> 2;
        row_index = (pixel_y - 11'd16) >> 2;
        decoded_cell = decode_cell(scaled_x);
        character_index = decoded_cell[6:3];
        column_index = decoded_cell[2:0];
        case (character_index)
            4'd0: character = "S";
            4'd1: character = "C";
            4'd2: character = "O";
            4'd3: character = "R";
            4'd4: character = "E";
            4'd5: character = " ";
            4'd6: character = 8'd48 + score[19:16];
            4'd7: character = 8'd48 + score[15:12];
            4'd8: character = 8'd48 + score[11:8];
            4'd9: character = 8'd48 + score[7:4];
            4'd10: character = 8'd48 + score[3:0];
            default: character = " ";
        endcase
        if (font_pixel(character, row_index, column_index)) begin
            pixel_on = 1'b1;
            color = 24'h00DFFF;
        end
    end

    // 2. WAVE 01..99 Banner. 4x scaling at top-right (1050, 16) to (1218, 44).
    if (pixel_x >= 11'd1050 && pixel_x < 11'd1218 && pixel_y >= 11'd16 && pixel_y < 11'd44) begin
        scaled_x = (pixel_x - 11'd1050) >> 2;
        row_index = (pixel_y - 11'd16) >> 2;
        decoded_cell = decode_cell(scaled_x);
        character_index = decoded_cell[6:3];
        column_index = decoded_cell[2:0];
        case (character_index)
            4'd0: character = "W";
            4'd1: character = "A";
            4'd2: character = "V";
            4'd3: character = "E";
            4'd5: character = wave_num >= 4'd10 ? "1" : "0";
            4'd6: character = 8'd48 + (wave_num >= 4'd10 ? (wave_num - 4'd10) : wave_num);
            default: character = " ";
        endcase
        if (font_pixel(character, row_index, column_index)) begin
            pixel_on = 1'b1;
            color = 24'hFFE600;
        end
    end

    // 3. Bottom Bar Labels (2x scaling, 12px wide per char, 14px tall at Y = 697..711)
    if (pixel_y >= 11'd697 && pixel_y < 11'd711) begin
        row_index = (pixel_y - 11'd697) >> 1;
        // 3a. "SHIPS" at X = 24..84
        if (pixel_x >= 11'd24 && pixel_x < 11'd84) begin
            scaled_x = (pixel_x - 11'd24) >> 1;
            decoded_cell = decode_cell(scaled_x);
            character_index = decoded_cell[6:3];
            column_index = decoded_cell[2:0];
            case (character_index)
                4'd0: character = "S";
                4'd1: character = "H";
                4'd2: character = "I";
                4'd3: character = "P";
                4'd4: character = "S";
                default: character = " ";
            endcase
            if (font_pixel(character, row_index, column_index)) begin
                pixel_on = 1'b1;
                color = 24'h33EEFF;
            end
        end
        // 3b. "POWER" at X = 200..260
        else if (pixel_x >= 11'd200 && pixel_x < 11'd260) begin
            scaled_x = (pixel_x - 11'd200) >> 1;
            decoded_cell = decode_cell(scaled_x);
            character_index = decoded_cell[6:3];
            column_index = decoded_cell[2:0];
            case (character_index)
                4'd0: character = "P";
                4'd1: character = "O";
                4'd2: character = "W";
                4'd3: character = "E";
                4'd4: character = "R";
                default: character = " ";
            endcase
            if (font_pixel(character, row_index, column_index)) begin
                pixel_on = 1'b1;
                color = 24'h44FFCC;
            end
        end
        // 3c. "LASER" at X = 948..1008
        else if (pixel_x >= 11'd948 && pixel_x < 11'd1008) begin
            scaled_x = (pixel_x - 11'd948) >> 1;
            decoded_cell = decode_cell(scaled_x);
            character_index = decoded_cell[6:3];
            column_index = decoded_cell[2:0];
            case (character_index)
                4'd0: character = "L";
                4'd1: character = "A";
                4'd2: character = "S";
                4'd3: character = "E";
                4'd4: character = "R";
                default: character = " ";
            endcase
            if (font_pixel(character, row_index, column_index)) begin
                pixel_on = 1'b1;
                color = 24'hDDEEFF;
            end
        end
    end

    // 4. Centered GAME OVER banner at (424, 440), 8x scaling, 432 visible pixels wide.
    if (game_over && pixel_x >= 11'd424 && pixel_x < 11'd856 &&
        pixel_y >= 11'd440 && pixel_y < 11'd496) begin
        scaled_x = (pixel_x - 11'd424) >> 3;
        row_index = (pixel_y - 11'd440) >> 3;
        decoded_cell = decode_cell(scaled_x);
        character_index = decoded_cell[6:3];
        column_index = decoded_cell[2:0];
        case (character_index)
            4'd0: character = "G";
            4'd1: character = "A";
            4'd2: character = "M";
            4'd3: character = "E";
            4'd5: character = "O";
            4'd6: character = "V";
            4'd7: character = "E";
            4'd8: character = "R";
            default: character = " ";
        endcase
        if (font_pixel(character, row_index, column_index)) begin
            pixel_on = 1'b1;
            color = 24'hFF1A1A;
        end
    end

    // 5. Centered WIN banner at (572,440), 8x scaling, 136 visible pixels wide.
    if (win && !game_over && pixel_x >= 11'd572 && pixel_x < 11'd716 &&
        pixel_y >= 11'd440 && pixel_y < 11'd496) begin
        scaled_x = (pixel_x - 11'd572) >> 3;
        row_index = (pixel_y - 11'd440) >> 3;
        decoded_cell = decode_cell(scaled_x);
        character_index = decoded_cell[6:3];
        column_index = decoded_cell[2:0];
        case (character_index)
            4'd0: character = "W";
            4'd1: character = "I";
            4'd2: character = "N";
            default: character = " ";
        endcase
        if (font_pixel(character, row_index, column_index)) begin
            pixel_on = 1'b1;
            color = 24'hFFFF00;
        end
    end

    // 6. Top-3 High Score Board when Scoreboard is active
    if (scoreboard_active && pixel_x >= 11'd508 && pixel_x < 11'd772) begin
        scaled_x = (pixel_x - 11'd508) >> 2;
        decoded_cell = decode_cell(scaled_x);
        character_index = decoded_cell[6:3];
        column_index = decoded_cell[2:0];
        if (pixel_y >= 11'd300 && pixel_y < 11'd328) begin
            row_index = (pixel_y - 11'd300) >> 2;
            case (character_index)
                4'd0: character = "1";
                4'd1: character = "S";
                4'd2: character = "T";
                4'd3: character = " ";
                4'd4: character = 8'd48 + score[19:16];
                4'd5: character = 8'd48 + score[15:12];
                4'd6: character = 8'd48 + score[11:8];
                4'd7: character = 8'd48 + score[7:4];
                4'd8: character = 8'd48 + score[3:0];
                default: character = " ";
            endcase
            if (font_pixel(character, row_index, column_index)) begin
                pixel_on = 1'b1;
                color = 24'hFFD700;
            end
        end else if (pixel_y >= 11'd344 && pixel_y < 11'd372) begin
            row_index = (pixel_y - 11'd344) >> 2;
            case (character_index)
                4'd0: character = "2";
                4'd1: character = "N";
                4'd2: character = "D";
                4'd3: character = " ";
                4'd4: character = 8'd48 + high_score_2[19:16];
                4'd5: character = 8'd48 + high_score_2[15:12];
                4'd6: character = 8'd48 + high_score_2[11:8];
                4'd7: character = 8'd48 + high_score_2[7:4];
                4'd8: character = 8'd48 + high_score_2[3:0];
                default: character = " ";
            endcase
            if (font_pixel(character, row_index, column_index)) begin
                pixel_on = 1'b1;
                color = 24'h44EEFF;
            end
        end else if (pixel_y >= 11'd388 && pixel_y < 11'd416) begin
            row_index = (pixel_y - 11'd388) >> 2;
            case (character_index)
                4'd0: character = "3";
                4'd1: character = "R";
                4'd2: character = "D";
                4'd3: character = " ";
                4'd4: character = 8'd48 + high_score_3[19:16];
                4'd5: character = 8'd48 + high_score_3[15:12];
                4'd6: character = 8'd48 + high_score_3[11:8];
                4'd7: character = 8'd48 + high_score_3[7:4];
                4'd8: character = 8'd48 + high_score_3[3:0];
                default: character = " ";
            endcase
            if (font_pixel(character, row_index, column_index)) begin
                pixel_on = 1'b1;
                color = 24'hFF9933;
            end
        end
    end
end

endmodule
