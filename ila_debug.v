// =============================================================================
// ILA Debug Core Wrapper
// For displaying waveforms using Vivado Integrated Logic Analyzer
// =============================================================================

module ila_waveform_debug (
    input  wire        clk,
    input  wire        rst_n,
    
    // Waveform signals to monitor
    input  wire [11:0] dac_out,
    input  wire [31:0] phase_acc,
    input  wire [19:0] current_freq,
    input  wire [1:0]  waveform_sel,
    input  wire [1:0]  sweep_mode,
    
    // Configuration signals
    input  wire [19:0] freq_config,
    input  wire [9:0]  phase_config,
    input  wire [6:0]  duty_config
);

    // =========================================================================
    // ILA IP Core Instantiation
    // =========================================================================
    // To use this, create an ILA IP core in Vivado with the following settings:
    // - Sample Data Depth: 4096 or more
    // - Number of Probes: 9
    // - Probe widths as specified below
    //
    // After implementation, you can capture waveforms in Vivado Hardware Manager
    
    // Note: This is a template. You need to generate the actual ILA IP core
    // in Vivado and instantiate it here.
    
    /*
    ila_0 u_ila (
        .clk(clk),
        .probe0(dac_out),           // [11:0] DAC output value
        .probe1(phase_acc[31:20]),  // [11:0] Phase (upper 12 bits)
        .probe2(current_freq),      // [19:0] Current frequency
        .probe3(waveform_sel),      // [1:0]  Waveform type
        .probe4(sweep_mode),        // [1:0]  Sweep mode
        .probe5(freq_config),       // [19:0] Configured frequency
        .probe6(phase_config),      // [9:0]  Configured phase
        .probe7(duty_config),       // [6:0]  Duty cycle
        .probe8(rst_n)              // [0:0]  Reset status
    );
    */

endmodule

// =============================================================================
// VIO Control Core Wrapper
// For runtime control of parameters using Virtual I/O
// =============================================================================

module vio_control (
    input  wire        clk,
    
    // VIO outputs (directly usable to control design)
    output wire [19:0] vio_freq,
    output wire [9:0]  vio_phase,
    output wire [1:0]  vio_waveform,
    output wire [1:0]  vio_sweep_mode,
    output wire        vio_enable
);

    // Note: This is a template. You need to generate the actual VIO IP core
    // in Vivado and instantiate it here.
    
    /*
    vio_0 u_vio (
        .clk(clk),
        .probe_out0(vio_freq),       // [19:0] Frequency control
        .probe_out1(vio_phase),      // [9:0]  Phase control
        .probe_out2(vio_waveform),   // [1:0]  Waveform selection
        .probe_out3(vio_sweep_mode), // [1:0]  Sweep mode selection
        .probe_out4(vio_enable)      // [0:0]  Enable signal
    );
    */
    
    // Default values when VIO is not connected
    assign vio_freq = 20'd100000;
    assign vio_phase = 10'd0;
    assign vio_waveform = 2'b00;
    assign vio_sweep_mode = 2'b00;
    assign vio_enable = 1'b1;

endmodule
