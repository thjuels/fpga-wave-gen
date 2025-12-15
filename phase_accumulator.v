// =============================================================================
// Phase Accumulator (Numerically Controlled Oscillator)
// Generates phase values for waveform synthesis
// =============================================================================

module phase_accumulator (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire [19:0] freq_word,        // Frequency in Hz
    input  wire [9:0]  phase_offset,     // Phase offset (0-999 = 0 to 2pi)
    
    output reg  [31:0] phase_acc         // Phase accumulator output
);

    // =========================================================================
    // Frequency to Phase Increment Calculation
    // =========================================================================
    // For a 32-bit phase accumulator at 100MHz clock:
    // phase_increment = (freq_Hz * 2^32) / 100,000,000
    // 
    // Simplified: phase_increment = freq_Hz * 42.94967296
    // Using fixed point: phase_increment = freq_Hz * 42 + (freq_Hz * 61497) / 65536
    // 
    // More accurate approximation:
    // phase_increment = freq_Hz * 43 - freq_Hz/19
    // 
    // Best approach: Use lookup or direct multiplication
    // phase_increment ≈ freq_Hz * 43 (with ~0.1% error, acceptable for this application)
    
    wire [31:0] phase_increment;
    wire [25:0] freq_mult_43;
    wire [25:0] freq_adjustment;
    
    // freq * 43 = freq * 32 + freq * 8 + freq * 2 + freq
    assign freq_mult_43 = {freq_word, 5'b0} +  // freq * 32
                          {freq_word, 3'b0} +  // freq * 8
                          {freq_word, 1'b0} +  // freq * 2
                          {6'b0, freq_word};   // freq * 1
    
    // Fine adjustment for better accuracy
    // Subtract approximately freq/23 for better accuracy
    // freq/23 ≈ freq/32 + freq/128
    assign freq_adjustment = ({6'b0, freq_word} >> 5) + ({6'b0, freq_word} >> 7);
    
    assign phase_increment = {6'b0, freq_mult_43} - {6'b0, freq_adjustment};
    
    // =========================================================================
    // Phase Offset Calculation
    // =========================================================================
    // Convert phase_offset (0-999) to 32-bit phase value
    // phase_offset_32 = (phase_offset * 2^32) / 1000 ≈ phase_offset * 4294967
    wire [31:0] phase_offset_32;
    assign phase_offset_32 = ({phase_offset, 22'b0}) +           // * 4194304
                             ({6'b0, phase_offset, 16'b0}) +     // * 65536
                             ({7'b0, phase_offset, 15'b0}) +     // * 32768
                             ({10'b0, phase_offset, 12'b0}) +    // * 4096
                             ({13'b0, phase_offset, 9'b0}) +     // * 512
                             ({16'b0, phase_offset, 6'b0}) +     // * 64
                             ({19'b0, phase_offset, 0'b0});      // * 1
    
    // =========================================================================
    // Phase Accumulator
    // =========================================================================
    reg [31:0] phase_raw;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_raw <= 32'd0;
        end else begin
            phase_raw <= phase_raw + phase_increment;
        end
    end
    
    // Add phase offset to raw phase
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= 32'd0;
        end else begin
            phase_acc <= phase_raw + phase_offset_32;
        end
    end

endmodule
