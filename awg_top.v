// =============================================================================
// Arbitrary Waveform Generator - Top Level Module
// Target FPGA: XC7A35T-ICPG236C (Basys3)
// =============================================================================

module awg_top (
    input  wire        clk,           // 100MHz system clock
    input  wire        rst_n,         // Active low reset (directly usable)
    
    // Button inputs (directly active high, directly usable)
    input  wire        btn_up,        // Increase value
    input  wire        btn_down,      // Decrease value
    input  wire        btn_left,      // Previous digit / mode
    input  wire        btn_right,     // Next digit / mode
    input  wire        btn_center,    // Confirm / Enter
    
    // Switch inputs
    input  wire [1:0]  sw_waveform,   // 00: Sine, 01: Sawtooth, 10: Triangle, 11: Square
    input  wire [1:0]  sw_sweep_mode, // 00: No sweep, 01: Linear, 10: Sinusoidal
    input  wire [1:0]  sw_duty_sel,   // Duty cycle: 00=1/2, 01=1/3, 10=1/4, 11=1/7
    input  wire        sw_phase_mode, // 0: Frequency config, 1: Phase config
    input  wire        sw_cont_duty,  // 0: Fixed duty, 1: Continuous duty adjustment mode
    input  wire        sw_cont_freq,  // (unused, kept for compatibility)
    input  wire        sw_pulse_mode, // 0: Normal AWG, 1: MHz Pulse Generator
    input  wire        sw_sweep_range_mode, // 0: Normal, 1: Edit sweep range (0-50 kHz)
    input  wire        sw_sweep_speed_mode, // 0: Normal, 1: Edit sweep speed (0-4 kHz/ms)
    input  wire        sw_hz_mode,    // 0: Edit kHz digits, 1: Edit Hz digits (bottom 3)
    
    // 7-segment display outputs
    output wire [6:0]  seg,           // Segment outputs (active low)
    output wire [3:0]  an,            // Digit anodes (active low)
    output wire        dp,            // Decimal point
    
    // DAC output (directly usable)
    output wire [11:0] dac_out,       // 12-bit DAC output
    
    // LED indicators
    output wire [15:0] led            // Status LEDs
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    
    // Synchronized and debounced button signals
    wire btn_up_pulse, btn_down_pulse, btn_left_pulse, btn_right_pulse, btn_center_pulse;
    
    // Configuration registers
    wire [19:0] freq_config;          // Frequency in Hz (1 to 999999)
    wire [9:0]  phase_config;         // Phase offset (0-999, representing 0 to 2pi)
    wire [6:0]  duty_config;          // Duty cycle (1-99 for 1% to 99%)
    wire [16:0] sweep_range;          // Sweep range in Hz (0 to 50000)
    wire [12:0] sweep_speed;          // Sweep speed in Hz/ms (0 to 4000)
    
    // Waveform generator outputs
    wire [11:0] wave_sine, wave_saw, wave_tri, wave_square;
    wire [11:0] wave_selected;
    
    // Frequency control
    wire [19:0] current_freq;         // Current frequency after sweep modulation
    wire [31:0] phase_acc;            // Phase accumulator value
    
    // Display data
    wire [19:0] display_value;
    wire [3:0]  display_mode;
    wire [2:0]  display_cursor;
    
    // =========================================================================
    // Clock Generation - Using 100MHz directly
    // =========================================================================
    wire clk_100mhz = clk;
    wire locked = 1'b1;  // No PLL needed for basic operation
    
    // =========================================================================
    // Input Processing Module - Button Debouncing
    // =========================================================================
    button_debounce u_btn_up (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .btn_in(btn_up),
        .btn_pulse(btn_up_pulse)
    );
    
    button_debounce u_btn_down (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .btn_in(btn_down),
        .btn_pulse(btn_down_pulse)
    );
    
    button_debounce u_btn_left (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .btn_in(btn_left),
        .btn_pulse(btn_left_pulse)
    );
    
    button_debounce u_btn_right (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .btn_in(btn_right),
        .btn_pulse(btn_right_pulse)
    );
    
    button_debounce u_btn_center (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .btn_in(btn_center),
        .btn_pulse(btn_center_pulse)
    );
    
    // =========================================================================
    // Data Input Processing Module
    // =========================================================================
    input_processor u_input_proc (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .btn_up(btn_up_pulse),
        .btn_down(btn_down_pulse),
        .btn_left(btn_left_pulse),
        .btn_right(btn_right_pulse),
        .btn_center(btn_center_pulse),
        .sw_phase_mode(sw_phase_mode),
        .sw_cont_duty(sw_cont_duty),
        .sw_cont_freq(sw_cont_freq),
        .sw_sweep_mode(sw_sweep_mode),
        .sw_sweep_range_mode(sw_sweep_range_mode),
        .sw_sweep_speed_mode(sw_sweep_speed_mode),
        .sw_hz_mode(sw_hz_mode),
        .sw_pulse_mode(sw_pulse_mode),
        .freq_out(freq_config),
        .phase_out(phase_config),
        .duty_out(duty_config),
        .sweep_range_out(sweep_range),
        .sweep_speed_out(sweep_speed),
        .display_value(display_value),
        .display_mode(display_mode),
        .cursor_out(display_cursor)
    );
    
    // =========================================================================
    // Frequency Sweep Controller
    // =========================================================================
    sweep_controller u_sweep (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .base_freq(freq_config),
        .sweep_mode(sw_sweep_mode),
        .sweep_range(sweep_range),
        .sweep_speed(sweep_speed),
        .current_freq(current_freq)
    );
    
    // =========================================================================
    // Phase Accumulator (NCO - Numerically Controlled Oscillator)
    // =========================================================================
    phase_accumulator u_nco (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .freq_word(current_freq),
        .phase_offset(phase_config),
        .phase_acc(phase_acc)
    );
    
    // =========================================================================
    // Waveform Generators
    // =========================================================================
    
    // Sine wave generator using lookup table
    sine_generator u_sine (
        .clk(clk_100mhz),
        .phase(phase_acc[31:20]),
        .sine_out(wave_sine)
    );
    
    // Sawtooth wave generator
    sawtooth_generator u_saw (
        .phase(phase_acc[31:20]),
        .saw_out(wave_saw)
    );
    
    // Triangle wave generator
    triangle_generator u_tri (
        .phase(phase_acc[31:20]),
        .tri_out(wave_tri)
    );
    
    // Square wave / pulse generator with adjustable duty cycle
    square_generator u_square (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .phase(phase_acc[31:20]),
        .duty_mode(sw_duty_sel),
        .duty_cont(duty_config),
        .cont_enable(sw_cont_duty),
        .square_out(wave_square)
    );
    
    // =========================================================================
    // MHz Pulse Generator (Expansion Requirement)
    // =========================================================================
    wire pulse_mhz_out;
    
    pulse_generator_mhz #(
        .N_MHZ(3) // Set to average of student ID last digits (e.g. 3 MHz)
    ) u_pulse_mhz (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .duty_mode(sw_duty_sel),
        .enable(sw_pulse_mode),
        .pulse_out(pulse_mhz_out)
    );
    
    // =========================================================================
    // Waveform Selection Multiplexer
    // =========================================================================
    reg [11:0] wave_mux;
    always @(*) begin
        if (sw_pulse_mode) begin
            // Output max or min value based on pulse
            wave_mux = pulse_mhz_out ? 12'hFFF : 12'h000;
        end else begin
            case (sw_waveform)
                2'b00: wave_mux = wave_sine;
                2'b01: wave_mux = wave_saw;
                2'b10: wave_mux = wave_tri;
                2'b11: wave_mux = wave_square;
            endcase
        end
    end
    
    assign wave_selected = wave_mux;
    assign dac_out = wave_selected;
    
    // =========================================================================
    // 7-Segment Display Controller
    // =========================================================================
    seven_seg_controller u_display (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .value(display_value),
        .mode(display_mode),
        .cursor(display_cursor),
        .seg(seg),
        .an(an),
        .dp(dp)
    );
    
    // =========================================================================
    // LED Status Indicators
    // =========================================================================
    assign led[1:0]   = sw_waveform;      // Current waveform type
    assign led[3:2]   = sw_sweep_mode;    // Current sweep mode
    assign led[4]     = sw_phase_mode;    // Phase config mode
    assign led[5]     = sw_cont_duty;     // Continuous duty mode
    assign led[6]     = sw_cont_freq;     // Continuous frequency mode
    assign led[7]     = locked;           // Clock locked
    assign led[15:8]  = wave_selected[11:4]; // Waveform amplitude indicator

    ila_waveform_debug ila_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dac_out(dac_out),
        .phase_acc(phase_acc),
        .current_freq(current_freq),
        .waveform_sel(sw_waveform),
        .sweep_mode(sw_sweep_mode),
        .freq_config(freq_val),
        .phase_config(phase_val),
        .duty_config(duty_cycle)
    );

endmodule
