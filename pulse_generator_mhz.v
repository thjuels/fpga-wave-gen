// =============================================================================
// High Frequency Pulse Generator
// Generates n MHz pulses with selectable duty cycles
// For the basic requirement: n = average of last digits of student IDs
// =============================================================================

module pulse_generator_mhz #(
    parameter N_MHZ = 3
)(
    input  wire        clk,           // 100 MHz system clock
    input  wire        rst_n,
    input  wire [1:0]  duty_mode,     // 00=1/2, 01=1/3, 10=1/4, 11=1/7
    input  wire        enable,         // Enable pulse generation
    output reg         pulse_out       // Pulse output
);

    // =========================================================================
    // Period Calculation
    // =========================================================================
    // For N MHz output with 100 MHz clock:
    // Period in clock cycles = 100 / N
    // 
    // Example: For 5 MHz output, period = 20 clock cycles
    
    localparam PERIOD = 100 / N_MHZ;  // Period in clock cycles
    
    // Duty cycle thresholds
    wire [6:0] threshold_half    = PERIOD / 2;
    wire [6:0] threshold_third   = PERIOD / 3;
    wire [6:0] threshold_quarter = PERIOD / 4;
    wire [6:0] threshold_seventh = PERIOD / 7;
    
    reg [6:0] threshold;
    reg [6:0] counter;
    
    // Select duty cycle threshold
    always @(*) begin
        case (duty_mode)
            2'b00: threshold = threshold_half;
            2'b01: threshold = threshold_third;
            2'b10: threshold = threshold_quarter;
            2'b11: threshold = threshold_seventh;
        endcase
    end
    
    // =========================================================================
    // Pulse Generation Counter
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 7'd0;
            pulse_out <= 1'b0;
        end else if (enable) begin
            if (counter >= PERIOD - 1) begin
                counter <= 7'd0;
            end else begin
                counter <= counter + 1'b1;
            end
            
            pulse_out <= (counter < threshold) ? 1'b1 : 1'b0;
        end else begin
            counter <= 7'd0;
            pulse_out <= 1'b0;
        end
    end

endmodule

// =============================================================================
// Parameterizable MHz Pulse Module for Different Frequencies
// This allows runtime selection of different MHz frequencies
// =============================================================================
module pulse_generator_variable (
    input  wire        clk,           // 100 MHz system clock
    input  wire        rst_n,
    input  wire [3:0]  freq_mhz,      // Target frequency in MHz (1-10)
    input  wire [1:0]  duty_mode,     // 00=1/2, 01=1/3, 10=1/4, 11=1/7
    input  wire        enable,
    output reg         pulse_out
);

    // Period lookup table for different frequencies
    reg [6:0] period;
    always @(*) begin
        case (freq_mhz)
            4'd1:  period = 7'd100;  // 1 MHz
            4'd2:  period = 7'd50;   // 2 MHz
            4'd3:  period = 7'd33;   // 3 MHz (approximate)
            4'd4:  period = 7'd25;   // 4 MHz
            4'd5:  period = 7'd20;   // 5 MHz
            4'd6:  period = 7'd17;   // 6 MHz (approximate)
            4'd7:  period = 7'd14;   // 7 MHz (approximate)
            4'd8:  period = 7'd13;   // 8 MHz (approximate)
            4'd9:  period = 7'd11;   // 9 MHz (approximate)
            4'd10: period = 7'd10;   // 10 MHz
            default: period = 7'd20; // Default 5 MHz
        endcase
    end
    
    // Calculate threshold based on duty cycle
    reg [6:0] threshold;
    always @(*) begin
        case (duty_mode)
            2'b00: threshold = period >> 1;          // 1/2
            2'b01: threshold = (period * 7'd21) >> 6; // ~1/3
            2'b10: threshold = period >> 2;          // 1/4
            2'b11: threshold = (period * 7'd9) >> 6;  // ~1/7
        endcase
    end
    
    reg [6:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 7'd0;
            pulse_out <= 1'b0;
        end else if (enable) begin
            if (counter >= period - 1) begin
                counter <= 7'd0;
            end else begin
                counter <= counter + 1'b1;
            end
            
            pulse_out <= (counter < threshold) ? 1'b1 : 1'b0;
        end else begin
            counter <= 7'd0;
            pulse_out <= 1'b0;
        end
    end

endmodule
