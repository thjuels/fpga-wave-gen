// =============================================================================
// Sweep Controller Module (FIXED)
// Implements linear and sinusoidal frequency sweeping
// =============================================================================

module sweep_controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // Configuration inputs
    input  wire [19:0] base_freq,        // Base frequency in Hz
    input  wire [1:0]  sweep_mode,       // 00: No sweep, 01: Linear fixed, 10: Sinusoidal, 11: Linear adjustable
    input  wire [16:0] sweep_range,      // Sweep range in Hz (max deviation)
    input  wire [12:0] sweep_speed,      // Sweep speed in Hz/ms
    input  wire        pulse_mode,       // 1: MHz pulse mode (output fixed frequency)
    
    // Output
    output reg  [19:0] current_freq      // Current instantaneous frequency
);

    // =========================================================================
    // Timing Generation
    // =========================================================================
    localparam CYCLES_PER_US = 100;
    localparam CYCLES_PER_MS = 100000;
    
    reg [6:0] us_counter;      // Only need 7 bits for 0-99
    reg [16:0] ms_counter;     // Only need 17 bits for 0-99999
    wire us_tick;
    wire ms_tick;
    
    // Microsecond tick generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            us_counter <= 7'd0;
        end else begin
            if (us_counter >= CYCLES_PER_US - 1)
                us_counter <= 7'd0;
            else
                us_counter <= us_counter + 1'b1;
        end
    end
    assign us_tick = (us_counter == CYCLES_PER_US - 1);
    
    // Millisecond tick generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms_counter <= 17'd0;
        end else begin
            if (ms_counter >= CYCLES_PER_MS - 1)
                ms_counter <= 17'd0;
            else
                ms_counter <= ms_counter + 1'b1;
        end
    end
    assign ms_tick = (ms_counter == CYCLES_PER_MS - 1);
    
    // =========================================================================
    // Linear Sweep Implementation
    // Triangular sweep trajectory
    // =========================================================================
    reg signed [17:0] linear_offset;
    reg               linear_direction;
    wire signed [17:0] sweep_range_signed;
    wire signed [17:0] fixed_sweep_range;
    
    assign sweep_range_signed = {1'b0, sweep_range};
    assign fixed_sweep_range = 18'sd20000;  // ±20kHz for mode 2'b01
    
    // For mode 2'b01: fixed asymmetric speeds
    localparam [12:0] UP_INCREMENT = 13'd1000;    // 1 kHz/μs
    localparam [12:0] DOWN_INCREMENT = 13'd1;     // 1 Hz/μs = 1 kHz/ms
    
    // For mode 2'b11: adjustable symmetric speed
    // sweep_speed is in Hz/ms, we update every μs, so divide by 1000
    // But division is expensive - use shift approximation or direct scaling
    // For simplicity: if sweep_speed = 1000 Hz/ms, increment = 1 Hz/μs
    wire [12:0] adjustable_increment;
    assign adjustable_increment = (sweep_speed >= 13'd1000) ? (sweep_speed / 13'd1000) : 13'd1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            linear_offset <= 18'sd0;
            linear_direction <= 1'b0;
        end else if (sweep_mode == 2'b01) begin
            // Fixed asymmetric linear sweep: up at 1kHz/μs, down at 1kHz/ms
            if (us_tick) begin
                if (!linear_direction) begin
                    // Increasing at 1 kHz/μs
                    if (linear_offset + $signed({5'b0, UP_INCREMENT}) >= fixed_sweep_range) begin
                        linear_offset <= fixed_sweep_range;
                        linear_direction <= 1'b1;
                    end else begin
                        linear_offset <= linear_offset + $signed({5'b0, UP_INCREMENT});
                    end
                end else begin
                    // Decreasing at 1 Hz/μs (1 kHz/ms)
                    if (linear_offset - $signed({5'b0, DOWN_INCREMENT}) <= -fixed_sweep_range) begin
                        linear_offset <= -fixed_sweep_range;
                        linear_direction <= 1'b0;
                    end else begin
                        linear_offset <= linear_offset - $signed({5'b0, DOWN_INCREMENT});
                    end
                end
            end
        end else if (sweep_mode == 2'b11) begin
            // Adjustable symmetric linear sweep
            if (us_tick) begin
                if (!linear_direction) begin
                    // Increasing at adjustable speed
                    if (linear_offset + $signed({5'b0, adjustable_increment}) >= sweep_range_signed) begin
                        linear_offset <= sweep_range_signed;
                        linear_direction <= 1'b1;
                    end else begin
                        linear_offset <= linear_offset + $signed({5'b0, adjustable_increment});
                    end
                end else begin
                    // Decreasing at same adjustable speed
                    if (linear_offset - $signed({5'b0, adjustable_increment}) <= -sweep_range_signed) begin
                        linear_offset <= -sweep_range_signed;
                        linear_direction <= 1'b0;
                    end else begin
                        linear_offset <= linear_offset - $signed({5'b0, adjustable_increment});
                    end
                end
            end
        end else begin
            linear_offset <= 18'sd0;
            linear_direction <= 1'b0;
        end
    end
    
    // =========================================================================
    // Sinusoidal Sweep Implementation (FIXED)
    // Uses a sine LUT for smooth sweeping
    // =========================================================================
    reg [11:0] sine_phase;
    reg [11:0] sine_phase_d1;        // Delayed phase for synchronization
    reg [11:0] sine_phase_d2;        // Double delayed for 2-cycle LUT latency
    wire [11:0] sine_value_raw;
    reg signed [17:0] sine_offset;
    
    // Phase increment based on sweep speed
    // Higher sweep_speed = faster modulation frequency
    wire [11:0] sine_phase_inc;
    // Scale: sweep_speed of 1000 Hz/ms should give reasonable modulation rate
    // With 12-bit phase (4096 steps) and μs updates:
    // Full cycle = 4096 μs at increment of 1
    // For sweep_speed = 1000, use increment ≈ 4 for ~1ms period
    assign sine_phase_inc = (sweep_speed[12:2] > 12'd0) ? sweep_speed[12:2] : 12'd1;
    
    // Phase accumulator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_phase <= 12'd0;
            sine_phase_d1 <= 12'd0;
            sine_phase_d2 <= 12'd0;
        end else if (sweep_mode == 2'b10) begin
            if (us_tick) begin
                sine_phase <= sine_phase + sine_phase_inc;
            end
            // Pipeline the phase to match LUT latency
            sine_phase_d1 <= sine_phase;
            sine_phase_d2 <= sine_phase_d1;
        end else begin
            sine_phase <= 12'd0;
            sine_phase_d1 <= 12'd0;
            sine_phase_d2 <= 12'd0;
        end
    end
    
    // Instantiate fixed sine LUT
    sine_lut_sweep u_sine_sweep (
        .clk(clk),
        .phase(sine_phase),
        .sine_out(sine_value_raw)
    );
    
    // Convert sine output to signed offset
    // sine_value_raw is 12-bit unsigned centered around 2048
    // Range: 0 to 4095, center at 2048
    wire signed [12:0] sine_centered;
    assign sine_centered = $signed({1'b0, sine_value_raw}) - 13'sd2048;
    // sine_centered range: -2048 to +2047
    
    // Scale sine to sweep range
    // We want: when sine_centered = ±2048, offset = ±sweep_range
    // So: offset = sine_centered * sweep_range / 2048
    // Use shift for division: / 2048 = >> 11
    wire signed [29:0] sine_scaled_full;
    assign sine_scaled_full = sine_centered * $signed({1'b0, sweep_range});
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_offset <= 18'sd0;
        end else begin
            // Divide by 2048 (shift right by 11) with sign extension
            sine_offset <= sine_scaled_full[28:11];
        end
    end
    
    // =========================================================================
    // Output Frequency Calculation (FIXED)
    // =========================================================================
    wire signed [20:0] freq_with_offset;
    reg signed [17:0] active_offset;
    
    // FIX: Include 2'b11 case for adjustable linear sweep
    always @(*) begin
        case (sweep_mode)
            2'b00:   active_offset = 18'sd0;           // No sweep
            2'b01:   active_offset = linear_offset;    // Linear sweep (fixed)
            2'b10:   active_offset = sine_offset;      // Sinusoidal sweep
            2'b11:   active_offset = linear_offset;    // Linear sweep (adjustable) <-- FIXED
        endcase
    end
    
    assign freq_with_offset = $signed({1'b0, base_freq}) + active_offset;
    
    // Clamp output frequency to valid range (1kHz to 999kHz)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_freq <= 20'd100000;
        end else begin
            if (pulse_mode) begin
                current_freq <= 20'd3000000;
            end else if (freq_with_offset < 21'sd1000) begin
                current_freq <= 20'd1000;
            end else if (freq_with_offset > 21'sd999000) begin
                current_freq <= 20'd999000;
            end else begin
                current_freq <= freq_with_offset[19:0];
            end
        end
    end

endmodule

// =============================================================================
// Sine LUT for Sweep Modulation (FIXED)
// Properly reconstructs full sine wave from quarter table
// =============================================================================
module sine_lut_sweep (
    input  wire        clk,
    input  wire [11:0] phase,
    output reg  [11:0] sine_out
);

    // 256-entry quarter sine table
    // Stores sin(0) to sin(π/2), scaled to 0-2047
    reg [10:0] quarter_sine [0:255];
    
    // Initialize quarter sine table
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            // sin(i * π / 512) scaled to 0-2047
            quarter_sine[i] = $rtoi(2047.0 * $sin(3.14159265359 * i / 512.0));
        end
    end
    
    // Phase decoding
    wire [1:0] quadrant;
    wire [7:0] index;
    wire [7:0] table_addr;
    
    assign quadrant = phase[11:10];
    assign index = phase[9:2];
    
    // Mirror index for quadrants 1 and 3 (where sine is decreasing from peak)
    assign table_addr = quadrant[0] ? (8'd255 - index) : index;
    
    // Pipeline registers for timing alignment
    reg [10:0] table_value;
    reg [1:0] quadrant_d1;
    
    // Stage 1: Read from table and register quadrant
    always @(posedge clk) begin
        table_value <= quarter_sine[table_addr];
        quadrant_d1 <= quadrant;
    end
    
    // Stage 2: Reconstruct full sine wave
    // Quadrant 0 (0 to π/2):     sine = table_value, positive, rising
    // Quadrant 1 (π/2 to π):     sine = table_value, positive, falling  
    // Quadrant 2 (π to 3π/2):    sine = -table_value, negative, falling
    // Quadrant 3 (3π/2 to 2π):   sine = -table_value, negative, rising
    always @(posedge clk) begin
        if (quadrant_d1[1] == 1'b0) begin
            // Quadrants 0 and 1: positive half (2048 + table_value)
            sine_out <= 12'd2048 + {1'b0, table_value};
        end else begin
            // Quadrants 2 and 3: negative half (2048 - table_value)
            sine_out <= 12'd2048 - {1'b0, table_value};
        end
    end

endmodule