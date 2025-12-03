// =============================================================================
// Sine Wave Generator
// Uses quarter-wave symmetry LUT for efficient sine generation
// =============================================================================

module sine_generator (
    input  wire        clk,
    input  wire [11:0] phase,      // 12-bit phase input (upper bits of accumulator)
    output reg  [11:0] sine_out    // 12-bit sine output (unsigned, 0-4095)
);

    // =========================================================================
    // Quarter-Wave Sine Lookup Table
    // =========================================================================
    // Using quarter-wave symmetry, we only need 1024 entries for full 4096 resolution
    // sin(x) for x in [0, pi/2] stored as unsigned values
    
    reg [11:0] sine_lut [0:1023];
    
    // Initialize LUT with sine values
    // sin(x) scaled to 0-2047, then offset to 2048 for unsigned representation
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            // Calculate sin value for quarter wave
            // angle = i * (pi/2) / 1024 = i * pi / 2048
            sine_lut[i] = 2048 + $rtoi(2047.0 * $sin(3.14159265359 * i / 2048.0));
        end
    end
    
    // =========================================================================
    // Quadrant-Based Sine Reconstruction
    // =========================================================================
    wire [1:0]  quadrant;
    wire [9:0]  lut_index;
    wire [9:0]  adjusted_index;
    reg  [11:0] lut_value;
    reg  [1:0]  quadrant_d1, quadrant_d2;
    
    assign quadrant = phase[11:10];
    assign lut_index = phase[9:0];
    
    // Adjust index based on quadrant (mirror for odd quadrants)
    assign adjusted_index = quadrant[0] ? (10'd1023 - lut_index) : lut_index;
    
    // Pipeline stage 1: LUT read
    always @(posedge clk) begin
        lut_value <= sine_lut[adjusted_index];
        quadrant_d1 <= quadrant;
    end
    
    // Pipeline stage 2: Quadrant adjustment
    always @(posedge clk) begin
        quadrant_d2 <= quadrant_d1;
    end
    
    // Final output with sign adjustment
    always @(posedge clk) begin
        if (quadrant_d2[1]) begin
            // Quadrants 2 and 3: negate (invert around 2048)
            sine_out <= 12'd4096 - lut_value;
        end else begin
            // Quadrants 0 and 1: direct value
            sine_out <= lut_value;
        end
    end

endmodule
