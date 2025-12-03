// =============================================================================
// 7-Segment Display Controller
// Drives 4-digit 7-segment display on Basys3
// =============================================================================

module seven_seg_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] value,      // 16-bit value to display
    input  wire [3:0]  mode,       // Display mode for formatting
    output reg  [6:0]  seg,        // Segment outputs (active low)
    output reg  [3:0]  an,         // Digit anodes (active low)
    output reg         dp          // Decimal point
);

    // =========================================================================
    // Refresh Rate Generation
    // =========================================================================
    // Target: ~1kHz refresh per digit, ~250Hz overall refresh
    // At 100MHz: divide by 100,000 for 1kHz
    
    parameter REFRESH_DIVIDER = 100000;
    
    reg [16:0] refresh_counter;
    reg [1:0]  digit_select;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_counter <= 17'd0;
            digit_select <= 2'd0;
        end else begin
            if (refresh_counter >= REFRESH_DIVIDER - 1) begin
                refresh_counter <= 17'd0;
                digit_select <= digit_select + 1'b1;
            end else begin
                refresh_counter <= refresh_counter + 1'b1;
            end
        end
    end
    
    // =========================================================================
    // BCD Conversion (Binary to BCD)
    // =========================================================================
    reg [3:0] digit0, digit1, digit2, digit3;
    reg [15:0] bcd_temp;
    integer j;
    
    // Double-dabble algorithm for binary to BCD
    always @(*) begin
        bcd_temp = 16'd0;
        for (j = 15; j >= 0; j = j - 1) begin
            // Check if any BCD digit is >= 5, if so add 3
            if (bcd_temp[3:0] >= 5)
                bcd_temp[3:0] = bcd_temp[3:0] + 4'd3;
            if (bcd_temp[7:4] >= 5)
                bcd_temp[7:4] = bcd_temp[7:4] + 4'd3;
            if (bcd_temp[11:8] >= 5)
                bcd_temp[11:8] = bcd_temp[11:8] + 4'd3;
            if (bcd_temp[15:12] >= 5)
                bcd_temp[15:12] = bcd_temp[15:12] + 4'd3;
            // Shift left and bring in next bit
            bcd_temp = {bcd_temp[14:0], value[j]};
        end
        digit0 = bcd_temp[3:0];
        digit1 = bcd_temp[7:4];
        digit2 = bcd_temp[11:8];
        digit3 = bcd_temp[15:12];
    end
    
    // =========================================================================
    // Digit Selection and Segment Encoding
    // =========================================================================
    reg [3:0] current_digit;
    
    // Select current digit value
    always @(*) begin
        case (digit_select)
            2'd0: current_digit = digit0;
            2'd1: current_digit = digit1;
            2'd2: current_digit = digit2;
            2'd3: current_digit = digit3;
        endcase
    end
    
    // Anode control (active low)
    always @(*) begin
        case (digit_select)
            2'd0: an = 4'b1110;
            2'd1: an = 4'b1101;
            2'd2: an = 4'b1011;
            2'd3: an = 4'b0111;
        endcase
    end
    
    // 7-segment encoding (active low)
    // Segment mapping: seg[6:0] = {g, f, e, d, c, b, a}
    //
    //    aaa
    //   f   b
    //    ggg
    //   e   c
    //    ddd
    //
    always @(*) begin
        case (current_digit)
            4'd0: seg = 7'b1000000;  // 0
            4'd1: seg = 7'b1111001;  // 1
            4'd2: seg = 7'b0100100;  // 2
            4'd3: seg = 7'b0110000;  // 3
            4'd4: seg = 7'b0011001;  // 4
            4'd5: seg = 7'b0010010;  // 5
            4'd6: seg = 7'b0000010;  // 6
            4'd7: seg = 7'b1111000;  // 7
            4'd8: seg = 7'b0000000;  // 8
            4'd9: seg = 7'b0010000;  // 9
            4'd10: seg = 7'b0001000; // A
            4'd11: seg = 7'b0000011; // b
            4'd12: seg = 7'b1000110; // C
            4'd13: seg = 7'b0100001; // d
            4'd14: seg = 7'b0000110; // E
            4'd15: seg = 7'b0001110; // F
        endcase
    end
    
    // Decimal point control based on mode
    always @(*) begin
        case (mode)
            4'd0: dp = (digit_select == 2'd2) ? 1'b0 : 1'b1;  // Freq mode: XX.XX kHz
            4'd1: dp = 1'b1;  // Phase mode: no DP
            4'd2: dp = 1'b1;  // Duty mode: no DP
            4'd3: dp = (digit_select == 2'd1) ? 1'b0 : 1'b1;  // Sweep range
            4'd4: dp = (digit_select == 2'd1) ? 1'b0 : 1'b1;  // Sweep speed
            default: dp = 1'b1;
        endcase
    end

endmodule
