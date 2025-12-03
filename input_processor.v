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
    input  wire        sw_cont_duty,     // Continuous duty adjustment
    input  wire        sw_cont_freq,     // 1Hz stride mode
    input  wire [1:0]  sw_sweep_mode,    // Sweep mode selection
    
    // Configuration outputs
    output reg  [19:0] freq_out,         // Frequency in Hz (1 to 999999)
    output reg  [9:0]  phase_out,        // Phase (0-999 for 0 to 2pi)
    output reg  [6:0]  duty_out,         // Duty cycle (1-99)
    output reg  [16:0] sweep_range_out,  // Sweep range in Hz (0-50000)
    output reg  [12:0] sweep_speed_out,  // Sweep speed in Hz/ms (0-4000)
    
    // Display outputs
    output reg  [15:0] display_value,
    output reg  [3:0]  display_mode
);

    // =========================================================================
    // Configuration State Machine
    // =========================================================================
    localparam MODE_FREQ        = 4'd0;
    localparam MODE_PHASE       = 4'd1;
    localparam MODE_DUTY        = 4'd2;
    localparam MODE_SWEEP_RANGE = 4'd3;
    localparam MODE_SWEEP_SPEED = 4'd4;
    
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
    
    // Digit multipliers for frequency adjustment
    reg [19:0] freq_digit_mult;
    always @(*) begin
        case (digit_select)
            3'd0: freq_digit_mult = sw_cont_freq ? 20'd1      : 20'd1000;
            3'd1: freq_digit_mult = sw_cont_freq ? 20'd10     : 20'd10000;
            3'd2: freq_digit_mult = sw_cont_freq ? 20'd100    : 20'd100000;
            3'd3: freq_digit_mult = sw_cont_freq ? 20'd1000   : 20'd1000;
            3'd4: freq_digit_mult = sw_cont_freq ? 20'd10000  : 20'd10000;
            3'd5: freq_digit_mult = sw_cont_freq ? 20'd100000 : 20'd100000;
            default: freq_digit_mult = 20'd1000;
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
            // Mode selection based on switches and button center
            if (btn_center) begin
                // Cycle through configuration modes when in sweep mode
                if (sw_sweep_mode != 2'b00) begin
                    case (config_mode)
                        MODE_FREQ:        config_mode <= MODE_SWEEP_RANGE;
                        MODE_SWEEP_RANGE: config_mode <= MODE_SWEEP_SPEED;
                        MODE_SWEEP_SPEED: config_mode <= MODE_FREQ;
                        default:          config_mode <= MODE_FREQ;
                    endcase
                end else if (sw_cont_duty) begin
                    config_mode <= (config_mode == MODE_DUTY) ? MODE_FREQ : MODE_DUTY;
                end
            end
            
            // Override mode based on switches
            if (sw_phase_mode && config_mode == MODE_FREQ) begin
                config_mode <= MODE_PHASE;
            end else if (!sw_phase_mode && config_mode == MODE_PHASE) begin
                config_mode <= MODE_FREQ;
            end
            
            // Digit selection (left/right)
            if (btn_left) begin
                digit_select <= (digit_select < 5) ? digit_select + 1'b1 : 3'd0;
            end
            if (btn_right) begin
                digit_select <= (digit_select > 0) ? digit_select - 1'b1 : 3'd5;
            end
            
            // Value adjustment (up/down)
            case (config_mode)
                MODE_FREQ: begin
                    if (btn_up) begin
                        if (freq_out + freq_digit_mult <= 20'd999999)
                            freq_out <= freq_out + freq_digit_mult;
                        else
                            freq_out <= 20'd999999;
                    end
                    if (btn_down) begin
                        if (freq_out > freq_digit_mult)
                            freq_out <= freq_out - freq_digit_mult;
                        else
                            freq_out <= 20'd1000;  // Minimum 1 kHz
                    end
                end
                
                MODE_PHASE: begin
                    if (btn_up) begin
                        if (phase_out < 10'd999)
                            phase_out <= phase_out + 1'b1;
                        else
                            phase_out <= 10'd0;
                    end
                    if (btn_down) begin
                        if (phase_out > 10'd0)
                            phase_out <= phase_out - 1'b1;
                        else
                            phase_out <= 10'd999;
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
                    if (btn_up) begin
                        if (sweep_range_out < 17'd50000)
                            sweep_range_out <= sweep_range_out + 17'd1000;
                    end
                    if (btn_down) begin
                        if (sweep_range_out > 17'd1000)
                            sweep_range_out <= sweep_range_out - 17'd1000;
                    end
                end
                
                MODE_SWEEP_SPEED: begin
                    if (btn_up) begin
                        if (sweep_speed_out < 13'd4000)
                            sweep_speed_out <= sweep_speed_out + 13'd100;
                    end
                    if (btn_down) begin
                        if (sweep_speed_out > 13'd100)
                            sweep_speed_out <= sweep_speed_out - 13'd100;
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
            MODE_FREQ:        display_value = freq_out[15:0];        // Show lower 16 bits
            MODE_PHASE:       display_value = {6'b0, phase_out};
            MODE_DUTY:        display_value = {9'b0, duty_out};
            MODE_SWEEP_RANGE: display_value = sweep_range_out[15:0];
            MODE_SWEEP_SPEED: display_value = {3'b0, sweep_speed_out};
            default:          display_value = freq_out[15:0];
        endcase
    end

endmodule
