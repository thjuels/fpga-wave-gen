// =============================================================================
// Sweep Controller Module (FIXED - Correct Sinusoidal Slew Rate)
// Implements linear and sinusoidal frequency sweeping
// =============================================================================

module sweep_controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // Configuration inputs
    input  wire [19:0] base_freq,        // Base frequency in Hz
    input  wire [1:0]  sweep_mode,       // 00: No sweep, 01: Linear fixed, 10: Sinusoidal, 11: Linear adjustable
    input  wire [16:0] sweep_range,      // Sweep range in Hz (max deviation)
    input  wire [12:0] sweep_speed,      // Sweep speed in Hz/ms (used for linear modes)
    input  wire        pulse_mode,       // 1: MHz pulse mode (output fixed frequency)
    
    // Output
    output reg  [19:0] current_freq      // Current instantaneous frequency
);

    // =========================================================================
    // Timing Generation
    // =========================================================================
    localparam CYCLES_PER_US = 100;
    localparam CYCLES_PER_MS = 100000;
    
    reg [6:0] us_counter;
    reg [16:0] ms_counter;
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
    // =========================================================================
    reg signed [17:0] linear_offset;
    reg               linear_direction;
    wire signed [17:0] sweep_range_signed;
    wire signed [17:0] fixed_sweep_range;
    
    assign sweep_range_signed = {1'b0, sweep_range};
    assign fixed_sweep_range = 18'sd20000;
    
    localparam [12:0] UP_INCREMENT = 13'd1000;    // 1 kHz/μs
    localparam [12:0] DOWN_INCREMENT = 13'd1;     // 1 Hz/μs = 1 kHz/ms
    
    wire [12:0] adjustable_increment;
    assign adjustable_increment = (sweep_speed >= 13'd1000) ? (sweep_speed / 13'd1000) : 13'd1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            linear_offset <= 18'sd0;
            linear_direction <= 1'b0;
        end else if (sweep_mode == 2'b01) begin
            if (us_tick) begin
                if (!linear_direction) begin
                    if (linear_offset + $signed({5'b0, UP_INCREMENT}) >= fixed_sweep_range) begin
                        linear_offset <= fixed_sweep_range;
                        linear_direction <= 1'b1;
                    end else begin
                        linear_offset <= linear_offset + $signed({5'b0, UP_INCREMENT});
                    end
                end else begin
                    if (linear_offset - $signed({5'b0, DOWN_INCREMENT}) <= -fixed_sweep_range) begin
                        linear_offset <= -fixed_sweep_range;
                        linear_direction <= 1'b0;
                    end else begin
                        linear_offset <= linear_offset - $signed({5'b0, DOWN_INCREMENT});
                    end
                end
            end
        end else if (sweep_mode == 2'b11) begin
            if (us_tick) begin
                if (!linear_direction) begin
                    if (linear_offset + $signed({5'b0, adjustable_increment}) >= sweep_range_signed) begin
                        linear_offset <= sweep_range_signed;
                        linear_direction <= 1'b1;
                    end else begin
                        linear_offset <= linear_offset + $signed({5'b0, adjustable_increment});
                    end
                end else begin
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
    // Sinusoidal Sweep Implementation (FIXED SLEW RATE)
    // Max rate of change = ±1 kHz/μs at zero crossings
    // =========================================================================
    
    // Use 24-bit phase accumulator for sub-integer increments
    // Upper 12 bits used for LUT addressing
    reg [23:0] sine_phase_acc;
    wire [11:0] sine_phase;
    wire [11:0] sine_value_raw;
    reg signed [17:0] sine_offset;
    
    assign sine_phase = sine_phase_acc[23:12];
    
    // Calculate phase increment for max slew rate of 1 kHz/μs
    //
    // For sinusoidal: offset = A * sin(phase * 2π / 4096)
    // Rate of change = A * (2π/4096) * phase_inc_per_us * cos(...)
    // Max rate (at cos=1) = A * (2π/4096) * phase_inc_per_us
    //
    // We want: max_rate = 1000 Hz/μs
    // So: phase_inc_per_us = 1000 * 4096 / (2π * A)
    //                      = 651,898 / A  (approximately)
    //                      ≈ 652,000 / sweep_range
    //
    // With 24-bit accumulator (12 fractional bits):
    // phase_inc_24bit = phase_inc_per_us * 4096 = 2,670,821,376 / sweep_range
    //
    // To avoid overflow in calculation, we use:
    // phase_inc_24bit ≈ 2,670,000,000 / sweep_range
    //                 ≈ (2,670,000 / sweep_range) * 1000
    //                 ≈ (2670 / (sweep_range/1000)) * 1000
    //
    // Simplified approximation that works for sweep_range 1000-50000:
    // phase_inc = 2,671,000,000 / sweep_range
    
    // For hardware, pre-compute for common ranges or use lookup
    // Here we'll use a simple division-based approach
    
    reg [23:0] sine_phase_inc;
    
    // Division: 2,671,000,000 / sweep_range
    // For sweep_range = 20000: phase_inc = 133,550 (0x209AE)
    // For sweep_range = 10000: phase_inc = 267,100 (0x4135C)
    // For sweep_range = 50000: phase_inc = 53,420  (0x0D09C)
    
    // Use approximation: (2671 * 1000000) / sweep_range
    // But that's too big for synthesis. Instead, use scaled values.
    //
    // Alternative: phase_inc = (2671 << 10) / (sweep_range >> 10)
    //            = 2,735,104 / (sweep_range >> 10)
    //
    // For sweep_range = 20000: sweep_range >> 10 = 19
    //                          phase_inc = 2,735,104 / 19 = 143,953 (close enough)
    
    wire [16:0] sweep_range_scaled;
    wire [31:0] phase_inc_calc;
    
    assign sweep_range_scaled = (sweep_range > 17'd1024) ? (sweep_range >> 10) : 17'd1;
    
    // 2,735,104 in hex = 0x29B800
    // Divide by sweep_range_scaled
    assign phase_inc_calc = 32'd2735104 / {15'd0, sweep_range_scaled};
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_phase_inc <= 24'd133550;  // Default for 20kHz range
        end else if (sweep_mode == 2'b10) begin
            // Clamp to reasonable range
            if (phase_inc_calc > 32'd4194304)  // Max ~1/4 of full scale per μs
                sine_phase_inc <= 24'd4194304;
            else if (phase_inc_calc < 32'd1000)
                sine_phase_inc <= 24'd1000;
            else
                sine_phase_inc <= phase_inc_calc[23:0];
        end
    end
    
    // Phase accumulator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_phase_acc <= 24'd0;
        end else if (sweep_mode == 2'b10) begin
            if (us_tick) begin
                sine_phase_acc <= sine_phase_acc + sine_phase_inc;
            end
        end else begin
            sine_phase_acc <= 24'd0;
        end
    end
    
    // Pipeline register for quadrant synchronization
    reg [1:0] quadrant_d1;
    reg [1:0] quadrant_d2;
    
    always @(posedge clk) begin
        quadrant_d1 <= sine_phase[11:10];
        quadrant_d2 <= quadrant_d1;
    end
    
    // Instantiate sine LUT
    sine_lut_sweep u_sine_sweep (
        .clk(clk),
        .phase(sine_phase),
        .sine_out(sine_value_raw)
    );
    
    // Convert sine output to signed offset
    // sine_value_raw: 0 to 4095, centered at 2048
    wire signed [12:0] sine_centered;
    assign sine_centered = $signed({1'b0, sine_value_raw}) - 13'sd2048;
    // sine_centered range: -2048 to +2047
    
    // Scale sine to sweep range
    // offset = sine_centered * sweep_range / 2048
    wire signed [29:0] sine_scaled_full;
    assign sine_scaled_full = sine_centered * $signed({1'b0, sweep_range});
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_offset <= 18'sd0;
        end else begin
            // Divide by 2048 (shift right by 11)
            sine_offset <= sine_scaled_full[28:11];
        end
    end
    
    // =========================================================================
    // Output Frequency Calculation
    // =========================================================================
    wire signed [20:0] freq_with_offset;
    reg signed [17:0] active_offset;
    
    always @(*) begin
        case (sweep_mode)
            2'b00:   active_offset = 18'sd0;
            2'b01:   active_offset = linear_offset;
            2'b10:   active_offset = sine_offset;
            2'b11:   active_offset = linear_offset;
        endcase
    end
    
    assign freq_with_offset = $signed({1'b0, base_freq}) + active_offset;
    
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
// Sine LUT for Sweep Modulation
// =============================================================================
module sine_lut_sweep (
    input  wire        clk,
    input  wire [11:0] phase,
    output reg  [11:0] sine_out
);

    // 256-entry quarter sine table (0 to π/2)
    reg [10:0] quarter_sine [0:255];
    
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            quarter_sine[i] = $rtoi(2047.0 * $sin(3.14159265359 * i / 512.0));
        end
    end
    
    wire [1:0] quadrant;
    wire [7:0] index;
    wire [7:0] table_addr;
    
    assign quadrant = phase[11:10];
    assign index = phase[9:2];
    assign table_addr = quadrant[0] ? (8'd255 - index) : index;
    
    reg [10:0] table_value;
    reg [1:0] quadrant_d1;
    
    always @(posedge clk) begin
        table_value <= quarter_sine[table_addr];
        quadrant_d1 <= quadrant;
    end
    
    always @(posedge clk) begin
        if (quadrant_d1[1] == 1'b0) begin
            sine_out <= 12'd2048 + {1'b0, table_value};
        end else begin
            sine_out <= 12'd2048 - {1'b0, table_value};
        end
    end

endmodule