// =============================================================================
// Input Processor Module
// Handles all user input for frequency, phase, duty cycle, and sweep configuration
// =============================================================================

module input_processor (
    input  wire        clk,
    input  wire        rst_n,
    
    // Button inputs (active high pulses)
    input  wire        btn_up,
    input  wire        btn_down,
    input  wire        btn_left,
    input  wire        btn_right,
    input  wire        btn_center,
    
    // Mode switches
    input  wire        sw_phase_mode,    // 0: Freq config, 1: Phase config
    input  wire        sw_cont_duty,     // Continuous duty adjustment mode
    input  wire        sw_cont_freq,     // (unused, kept for compatibility)
    input  wire [1:0]  sw_sweep_mode,    // Sweep mode selection
    input  wire        sw_sweep_range_mode, // Edit sweep range mode
    input  wire        sw_sweep_speed_mode, // Edit sweep speed mode
    input  wire        sw_hz_mode,       // Edit Hz digits (bottom 3)
    input  wire        sw_pulse_mode,    // MHz pulse mode (for display)
    
    // Configuration outputs
    output reg  [19:0] freq_out,         // Frequency in Hz (1 to 999999)
    output reg  [9:0]  phase_out,        // Phase (0-999 for 0 to 2pi)
    output reg  [6:0]  duty_out,         // Duty cycle (1-99)
    output reg  [16:0] sweep_range_out,  // Sweep range in Hz (0-50000)
    output reg  [12:0] sweep_speed_out,  // Sweep speed in Hz/ms (0-4000)
    
    // Display outputs
    output reg  [19:0] display_value,
    output reg  [3:0]  display_mode,
    output wire [2:0]  cursor_out
);

    assign cursor_out = digit_select;

    // =========================================================================
    // Configuration State Machine
    // =========================================================================
    localparam MODE_FREQ            = 4'd0;
    localparam MODE_PHASE           = 4'd1;
    localparam MODE_DUTY            = 4'd2;
    localparam MODE_SWEEP_RANGE     = 4'd3;
    localparam MODE_SWEEP_SPEED     = 4'd4;
    localparam MODE_FREQ_HZ         = 4'd5;  // Edit Hz portion (bottom 3 digits)
    localparam MODE_MHZ_PULSE       = 4'd6;  // MHz pulse display mode
    localparam MODE_ADJUSTABLE_FREQ = 4'd7;  // Adjustable frequency mode
    
    reg [3:0] config_mode;
    reg [2:0] digit_select;  // Which digit is being edited (0-5)
    
    // Default values
    localparam DEFAULT_FREQ        = 20'd100000;  // 100 kHz
    localparam DEFAULT_PHASE       = 10'd0;       // 0 phase
    localparam DEFAULT_DUTY        = 7'd50;       // 50%
    localparam DEFAULT_SWEEP_RANGE = 17'd20000;   // 20 kHz
    localparam DEFAULT_SWEEP_SPEED = 13'd1000;    // 1 kHz/ms
    
    // =========================================================================
    // Increment/Decrement Values Based on Mode and Stride
    // =========================================================================
    wire [19:0] freq_stride;
    assign freq_stride = sw_cont_freq ? 20'd1 : 20'd1000;  // 1 Hz or 1 kHz
    
    // Digit multipliers for frequency adjustment (kHz mode only)
    // digit_select 0 = 1 kHz, 1 = 10 kHz, 2 = 100 kHz
    reg [19:0] freq_digit_mult;
    always @(*) begin
        case (digit_select)
            3'd0: freq_digit_mult = 20'd1000;    // 1 kHz step
            3'd1: freq_digit_mult = 20'd10000;   // 10 kHz step
            3'd2: freq_digit_mult = 20'd100000;  // 100 kHz step
            default: freq_digit_mult = 20'd1000;
        endcase
    end
    
    // Digit multipliers for Hz mode (bottom 3 digits)
    // digit_select 0 = 1 Hz, 1 = 10 Hz, 2 = 100 Hz
    reg [19:0] hz_digit_mult;
    always @(*) begin
        case (digit_select)
            3'd0: hz_digit_mult = 20'd1;      // 1 Hz step
            3'd1: hz_digit_mult = 20'd10;     // 10 Hz step
            3'd2: hz_digit_mult = 20'd100;    // 100 Hz step
            default: hz_digit_mult = 20'd1;
        endcase
    end
    
    // Digit multipliers for phase adjustment (0-999)
    // digit_select 0 = 1s, 1 = 10s, 2 = 100s
    reg [9:0] phase_digit_mult;
    always @(*) begin
        case (digit_select)
            3'd0: phase_digit_mult = 10'd1;      // 1 step
            3'd1: phase_digit_mult = 10'd10;     // 10 step
            3'd2: phase_digit_mult = 10'd100;    // 100 step
            default: phase_digit_mult = 10'd1;
        endcase
    end
    
    // =========================================================================
    // Main Configuration Logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_out        <= DEFAULT_FREQ;
            phase_out       <= DEFAULT_PHASE;
            duty_out        <= DEFAULT_DUTY;
            sweep_range_out <= DEFAULT_SWEEP_RANGE;
            sweep_speed_out <= DEFAULT_SWEEP_SPEED;
            config_mode     <= MODE_FREQ;
            digit_select    <= 3'd0;
        end else begin
            // Mode selection based on switches (direct switch control)
            // Priority: pulse_mode > sweep_range > sweep_speed > adjustable_freq > duty > hz_mode > phase > freq
            if (sw_pulse_mode) begin
                config_mode <= MODE_MHZ_PULSE;
            end else if (sw_sweep_range_mode) begin
                config_mode <= MODE_SWEEP_RANGE;
            end else if (sw_sweep_speed_mode) begin
                config_mode <= MODE_SWEEP_SPEED;
            end else if (sw_sweep_mode == 2'b11) begin
                config_mode <= MODE_ADJUSTABLE_FREQ;
            end else if (sw_cont_duty) begin
                config_mode <= MODE_DUTY;
            end else if (sw_hz_mode) begin
                config_mode <= MODE_FREQ_HZ;
            end else if (sw_phase_mode) begin
                config_mode <= MODE_PHASE;
            end else begin
                config_mode <= MODE_FREQ;
            end
            
            // Digit selection (left/right) - only 3 digits (0, 1, 2)
            if (btn_left) begin
                digit_select <= (digit_select < 2) ? digit_select + 1'b1 : 3'd0;
            end
            if (btn_right) begin
                digit_select <= (digit_select > 0) ? digit_select - 1'b1 : 3'd2;
            end
            
            // Value adjustment (up/down)
            case (config_mode)
                MODE_FREQ: begin
                    // Frequency range: 1 kHz (1000 Hz) to 999 kHz (999000 Hz)
                    if (btn_up) begin
                        if (freq_out + freq_digit_mult <= 20'd999999)
                            freq_out <= freq_out + freq_digit_mult;
                        else
                            freq_out <= 20'd999999;  // Maximum 999.999 kHz
                    end
                    if (btn_down) begin
                        if (freq_out > freq_digit_mult && (freq_out - freq_digit_mult) >= 20'd1000)
                            freq_out <= freq_out - freq_digit_mult;
                        else
                            freq_out <= 20'd1000;  // Minimum 1 kHz
                    end
                end
                
                MODE_FREQ_HZ: begin
                    // Edit Hz portion (bottom 3 digits: 0-999 Hz)
                    if (btn_up) begin
                        if (freq_out + hz_digit_mult <= 20'd999999)
                            freq_out <= freq_out + hz_digit_mult;
                        else
                            freq_out <= 20'd999999;  // Maximum
                    end
                    if (btn_down) begin
                        if (freq_out > hz_digit_mult && (freq_out - hz_digit_mult) >= 20'd1000)
                            freq_out <= freq_out - hz_digit_mult;
                        else
                            freq_out <= 20'd1000;  // Minimum 1 kHz
                    end
                end
                
                MODE_PHASE: begin
                    // Phase range: 0-999 (representing 0 to 2pi)
                    if (btn_up) begin
                        if (phase_out + phase_digit_mult <= 10'd999)
                            phase_out <= phase_out + phase_digit_mult;
                        else
                            phase_out <= 10'd999;  // Maximum
                    end
                    if (btn_down) begin
                        if (phase_out >= phase_digit_mult)
                            phase_out <= phase_out - phase_digit_mult;
                        else
                            phase_out <= 10'd0;  // Minimum
                    end
                end
                
                MODE_ADJUSTABLE_FREQ: begin
                    // Adjustable frequency mode: continuous adjustment with 1kHz steps
                    if (btn_up) begin
                        if (freq_out + 20'd1000 <= 20'd999999)
                            freq_out <= freq_out + 20'd1000;  // +1 kHz
                        else
                            freq_out <= 20'd999999;  // Maximum
                    end
                    if (btn_down) begin
                        if (freq_out >= 20'd1000 + 20'd1000)
                            freq_out <= freq_out - 20'd1000;  // -1 kHz
                        else
                            freq_out <= 20'd1000;  // Minimum 1 kHz
                    end
                end
                
                MODE_DUTY: begin
                    if (btn_up) begin
                        if (duty_out < 7'd99)
                            duty_out <= duty_out + 1'b1;
                    end
                    if (btn_down) begin
                        if (duty_out > 7'd1)
                            duty_out <= duty_out - 1'b1;
                    end
                end
                
                MODE_SWEEP_RANGE: begin
                    // Sweep range: 0-50 kHz (stored as Hz, displayed as kHz)
                    if (btn_up) begin
                        if (sweep_range_out < 17'd50000)
                            sweep_range_out <= sweep_range_out + 17'd1000;  // +1 kHz
                    end
                    if (btn_down) begin
                        if (sweep_range_out >= 17'd1000)
                            sweep_range_out <= sweep_range_out - 17'd1000;  // -1 kHz
                        else
                            sweep_range_out <= 17'd0;  // Minimum 0 kHz
                    end
                end
                
                MODE_SWEEP_SPEED: begin
                    // Sweep speed: 0-4 kHz/ms (stored as Hz/ms, displayed as kHz/ms)
                    if (btn_up) begin
                        if (sweep_speed_out < 13'd4000)
                            sweep_speed_out <= sweep_speed_out + 13'd1000;  // +1 kHz/ms
                    end
                    if (btn_down) begin
                        if (sweep_speed_out >= 13'd1000)
                            sweep_speed_out <= sweep_speed_out - 13'd1000;  // -1 kHz/ms
                        else
                            sweep_speed_out <= 13'd0;  // Minimum 0 kHz/ms
                    end
                end
            endcase
        end
    end
    
    // =========================================================================
    // Display Value Selection
    // =========================================================================
    always @(*) begin
        display_mode = config_mode;
        case (config_mode)
            MODE_FREQ:            display_value = freq_out / 20'd1000;           // Show in kHz (1-999)
            MODE_FREQ_HZ:         display_value = freq_out % 20'd1000;           // Show Hz portion (0-999)
            MODE_PHASE:           display_value = {10'b0, phase_out};            // Show 0-999
            MODE_DUTY:            display_value = {13'b0, duty_out};             // Show 1-99 (%)
            MODE_SWEEP_RANGE:     display_value = sweep_range_out / 17'd1000;    // Show in kHz (0-50)
            MODE_SWEEP_SPEED:     display_value = sweep_speed_out / 13'd1000;    // Show in kHz/ms (0-4)
            MODE_MHZ_PULSE:       display_value = 20'd3;                         // Show MHz frequency (3 MHz)
            MODE_ADJUSTABLE_FREQ: display_value = freq_out / 20'd1000;           // Show in kHz (1-999)
            default:              display_value = freq_out / 20'd1000;
        endcase
    end

endmodule
