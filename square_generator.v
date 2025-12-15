// =============================================================================
// Square Wave / Pulse Generator
// Generates square pulse with adjustable duty cycle
// Supports fixed duty cycles (1/2, 1/3, 1/4, 1/7) and continuous adjustment
// =============================================================================

module square_generator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] phase,          // 12-bit phase input
    input  wire [1:0]  duty_mode,      // Fixed duty: 00=1/2, 01=1/3, 10=1/4, 11=1/7
    input  wire [6:0]  duty_cont,      // Continuous duty (1-99%)
    input  wire        cont_enable,    // Enable continuous duty mode
    output wire [11:0] square_out      // 12-bit square output
);

    // =========================================================================
    // Duty Cycle Threshold Calculation
    // =========================================================================
    // Phase value at which output transitions from high to low
    // threshold = 4096 * duty_cycle
    
    reg [11:0] threshold;
    
    // Fixed duty cycle thresholds
    wire [11:0] threshold_half    = 12'd2048;  // 50% duty
    wire [11:0] threshold_third   = 12'd1365;  // 33.3% duty (4096/3)
    wire [11:0] threshold_quarter = 12'd1024;  // 25% duty (4096/4)
    wire [11:0] threshold_seventh = 12'd585;   // 14.3% duty (4096/7)
    
    // Continuous duty cycle threshold
    // threshold = (duty_cont * 4096) / 100
    // Using approximation: duty_cont * 41 (close to 4096/100 = 40.96)
    // For duty_cont = 99: 99 * 41 = 4059 ≈ 4096 * 0.99
    // For duty_cont = 50: 50 * 41 = 2050 ≈ 4096 * 0.50
    // For duty_cont = 1:  1 * 41  = 41   ≈ 4096 * 0.01
    wire [12:0] cont_product;
    wire [11:0] threshold_cont;

    assign cont_product   = {6'b0, duty_cont} * 13'd41;  // duty_cont * 41
    assign threshold_cont = cont_product[11:0];          // Use lower 12 bits directly (no division)

    always @(*) begin
        if (cont_enable) begin
            threshold = threshold_cont;
        end else begin
            case (duty_mode)
            2'b00: threshold = threshold_half;
            2'b01: threshold = threshold_third;
            2'b10: threshold = threshold_quarter;
            2'b11: threshold = threshold_seventh;
            endcase
        end
    end
    
    // =========================================================================
    // Square Wave Generation
    // =========================================================================
    // Output is high when phase < threshold
    
    wire pulse_high;
    assign pulse_high = (phase < threshold);
    
    // Output full scale (4095 for high, 0 for low)
    assign square_out = pulse_high ? 12'd4095 : 12'd0;

endmodule
