module font_rom (
    input  wire [7:0] char_code,
    input  wire [2:0] row,
    output reg  [4:0] pixels
);

    always @* begin
        pixels = 5'b00000;

        case (char_code)

            "A": case (row)
                0: pixels = 5'b01110;
                1: pixels = 5'b10001;
                2: pixels = 5'b10001;
                3: pixels = 5'b11111;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b10001;
            endcase

            "B": case (row)
                0: pixels = 5'b11110;
                1: pixels = 5'b10001;
                2: pixels = 5'b10001;
                3: pixels = 5'b11110;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b11110;
            endcase

            "C": case (row)
                0: pixels = 5'b01110;
                1: pixels = 5'b10001;
                2: pixels = 5'b10000;
                3: pixels = 5'b10000;
                4: pixels = 5'b10000;
                5: pixels = 5'b10001;
                6: pixels = 5'b01110;
            endcase

            "D": case (row)
                0: pixels = 5'b11110;
                1: pixels = 5'b10001;
                2: pixels = 5'b10001;
                3: pixels = 5'b10001;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b11110;
            endcase

            "E": case (row)
                0: pixels = 5'b11111;
                1: pixels = 5'b10000;
                2: pixels = 5'b10000;
                3: pixels = 5'b11110;
                4: pixels = 5'b10000;
                5: pixels = 5'b10000;
                6: pixels = 5'b11111;
            endcase

            "F": case (row)
                0: pixels = 5'b11111;
                1: pixels = 5'b10000;
                2: pixels = 5'b10000;
                3: pixels = 5'b11110;
                4: pixels = 5'b10000;
                5: pixels = 5'b10000;
                6: pixels = 5'b10000;
            endcase

            "G": case (row)
                0: pixels = 5'b01110;
                1: pixels = 5'b10001;
                2: pixels = 5'b10000;
                3: pixels = 5'b10111;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b01110;
            endcase

            "H": case (row)
                0: pixels = 5'b10001;
                1: pixels = 5'b10001;
                2: pixels = 5'b10001;
                3: pixels = 5'b11111;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b10001;
            endcase

            "L": case (row)
                0: pixels = 5'b10000;
                1: pixels = 5'b10000;
                2: pixels = 5'b10000;
                3: pixels = 5'b10000;
                4: pixels = 5'b10000;
                5: pixels = 5'b10000;
                6: pixels = 5'b11111;
            endcase

            "M": case (row)
                0: pixels = 5'b10001;
                1: pixels = 5'b11011;
                2: pixels = 5'b10101;
                3: pixels = 5'b10101;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b10001;
            endcase

            "N": case (row)
                0: pixels = 5'b10001;
                1: pixels = 5'b11001;
                2: pixels = 5'b10101;
                3: pixels = 5'b10011;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b10001;
            endcase

            "O": case (row)
                0: pixels = 5'b01110;
                1: pixels = 5'b10001;
                2: pixels = 5'b10001;
                3: pixels = 5'b10001;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b01110;
            endcase

            "R": case (row)
                0: pixels = 5'b11110;
                1: pixels = 5'b10001;
                2: pixels = 5'b10001;
                3: pixels = 5'b11110;
                4: pixels = 5'b10100;
                5: pixels = 5'b10010;
                6: pixels = 5'b10001;
            endcase

            "S": case (row)
                0: pixels = 5'b01111;
                1: pixels = 5'b10000;
                2: pixels = 5'b10000;
                3: pixels = 5'b01110;
                4: pixels = 5'b00001;
                5: pixels = 5'b00001;
                6: pixels = 5'b11110;
            endcase

            "T": case (row)
                0: pixels = 5'b11111;
                1: pixels = 5'b00100;
                2: pixels = 5'b00100;
                3: pixels = 5'b00100;
                4: pixels = 5'b00100;
                5: pixels = 5'b00100;
                6: pixels = 5'b00100;
            endcase

            "U": case (row)
                0: pixels = 5'b10001;
                1: pixels = 5'b10001;
                2: pixels = 5'b10001;
                3: pixels = 5'b10001;
                4: pixels = 5'b10001;
                5: pixels = 5'b10001;
                6: pixels = 5'b01110;
            endcase

            "W": case (row)
                0: pixels = 5'b10001;
                1: pixels = 5'b10001;
                2: pixels = 5'b10001;
                3: pixels = 5'b10101;
                4: pixels = 5'b10101;
                5: pixels = 5'b11011;
                6: pixels = 5'b01010;
            endcase

            "Y": case (row)
                0: pixels = 5'b10001;
                1: pixels = 5'b10001;
                2: pixels = 5'b01010;
                3: pixels = 5'b00100;
                4: pixels = 5'b00100;
                5: pixels = 5'b00100;
                6: pixels = 5'b00100;
            endcase

            default:
                pixels = 5'b00000;

        endcase
    end

endmodule