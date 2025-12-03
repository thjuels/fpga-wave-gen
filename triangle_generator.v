// =============================================================================
// Triangle Wave Generator
// Generates symmetric triangle waveform from phase input
// =============================================================================

module triangle_generator (
    input  wire [11:0] phase,      // 12-bit phase input
    output wire [11:0] tri_out     // 12-bit triangle output
);

    // =========================================================================
    // Triangle Generation
    // =========================================================================
    // Triangle wave: rises from 0 to max in first half, falls back to 0 in second half
    // 
    // For phase 0 to 2047: output = phase * 2
    // For phase 2048 to 4095: output = (4095 - phase) * 2
    //
    // Simplified using MSB as direction indicator
    
    wire rising;
    wire [10:0] half_phase;
    wire [11:0] tri_value;
    
    assign rising = ~phase[11];  // Rising when MSB is 0
    assign half_phase = phase[10:0];
    
    // Double the half-phase value for full range
    assign tri_value = rising ? {half_phase, 1'b0} : {11'd2047 - half_phase, 1'b0} + 12'd1;
    
    // Alternative cleaner implementation:
    // When rising (phase[11]=0): output = phase * 2 (using lower 11 bits, doubled)
    // When falling (phase[11]=1): output = (4095 - phase) * 2
    
    wire [11:0] tri_rising, tri_falling;
    assign tri_rising = {phase[10:0], 1'b0};                           // phase * 2
    assign tri_falling = {(11'd2047 - phase[10:0]), 1'b0} + 12'd1;    // inverted
    
    assign tri_out = rising ? tri_rising : tri_falling;

endmodule
