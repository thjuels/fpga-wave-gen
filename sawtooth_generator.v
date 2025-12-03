// =============================================================================
// Sawtooth Wave Generator
// Generates rising sawtooth waveform from phase input
// =============================================================================

module sawtooth_generator (
    input  wire [11:0] phase,      // 12-bit phase input
    output wire [11:0] saw_out     // 12-bit sawtooth output
);

    // =========================================================================
    // Sawtooth Generation
    // =========================================================================
    // Sawtooth is simply the phase value itself, linearly mapping
    // phase 0 to output 0, phase 4095 to output 4095
    
    assign saw_out = phase;

endmodule
