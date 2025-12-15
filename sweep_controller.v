// =============================================================================
// Sweep Controller Module
// Implements linear and sinusoidal frequency sweeping
// =============================================================================

module sweep_controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // Configuration inputs
    input  wire [19:0] base_freq,        // Base frequency in Hz
    input  wire [1:0]  sweep_mode,       // 00: No sweep, 01: Linear, 10: Sinusoidal
    input  wire [16:0] sweep_range,      // Sweep range in Hz (max deviation)
    input  wire [12:0] sweep_speed,      // Sweep speed in Hz/ms
    input  wire        pulse_mode,       // 1: MHz pulse mode (output fixed frequency)
    
    // Output
    output reg  [19:0] current_freq      // Current instantaneous frequency
);

    // =========================================================================
    // Timing Generation
    // =========================================================================
    // At 100MHz, 1us = 100 cycles, 1ms = 100,000 cycles
    localparam CYCLES_PER_US = 100;
    localparam CYCLES_PER_MS = 100000;
    
    reg [16:0] us_counter;
    reg [19:0] ms_counter;
    wire us_tick;
    wire ms_tick;
    
    // Microsecond tick generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            us_counter <= 17'd0;
        end else begin
            if (us_counter >= CYCLES_PER_US - 1)
                us_counter <= 17'd0;
            else
                us_counter <= us_counter + 1'b1;
        end
    end
    assign us_tick = (us_counter == CYCLES_PER_US - 1);
    
    // Millisecond tick generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms_counter <= 20'd0;
        end else begin
            if (ms_counter >= CYCLES_PER_MS - 1)
                ms_counter <= 20'd0;
            else
                ms_counter <= ms_counter + 1'b1;
        end
    end
    assign ms_tick = (ms_counter == CYCLES_PER_MS - 1);
    
    // =========================================================================
    // Linear Sweep Implementation
    // Triangular sweep trajectory
    // =========================================================================
    reg signed [17:0] linear_offset;     // Current frequency offset
    reg               linear_direction;   // 0: increasing, 1: decreasing
    wire signed [17:0] sweep_range_signed;
    
    assign sweep_range_signed = {1'b0, sweep_range};
    
    // Calculate sweep increment per step
    // sweep_speed is in Hz/ms, convert to Hz/us by dividing by 1000
    wire [12:0] linear_increment;
    assign linear_increment = sweep_speed / 13'd1000;  // Proper division by 1000
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            linear_offset <= 18'sd0;
            linear_direction <= 1'b0;
        end else if (sweep_mode == 2'b01) begin  // Linear sweep mode
            if (us_tick) begin // Update every microsecond for high speed sweep
                if (!linear_direction) begin
                    // Increasing frequency
                    if (linear_offset + $signed({5'b0, linear_increment}) >= sweep_range_signed) begin
                        linear_offset <= sweep_range_signed;
                        linear_direction <= 1'b1;
                    end else begin
                        linear_offset <= linear_offset + $signed({5'b0, linear_increment});
                    end
                end else begin
                    // Decreasing frequency
                    if (linear_offset - $signed({5'b0, linear_increment}) <= -sweep_range_signed) begin
                        linear_offset <= -sweep_range_signed;
                        linear_direction <= 1'b0;
                    end else begin
                        linear_offset <= linear_offset - $signed({5'b0, linear_increment});
                    end
                end
            end
        end else begin
            linear_offset <= 18'sd0;
            linear_direction <= 1'b0;
        end
    end
    
    // =========================================================================
    // Sinusoidal Sweep Implementation
    // Uses a sine LUT for smooth sweeping
    // =========================================================================
    reg [11:0] sine_phase;           // Phase for sweep sine wave
    wire [11:0] sine_value;          // Sine LUT output
    reg signed [17:0] sine_offset;
    
    // Sine LUT for sweep modulation
    sine_lut_sweep u_sine_sweep (
        .clk(clk),
        .phase(sine_phase),
        .sine_out(sine_value)
    );
    
    // Calculate phase increment for sweep sine wave
    // Period should give max rate of sweep_speed Hz/ms at peak
    reg [15:0] sine_phase_inc;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_phase <= 12'd0;
            sine_phase_inc <= 16'd10;  // Default slow sweep
        end else if (sweep_mode == 2'b10) begin  // Sinusoidal sweep mode
            if (us_tick) begin // Update every microsecond
                sine_phase <= sine_phase + sine_phase_inc[11:0];
            end
            // Adjust phase increment based on sweep_speed
            // Higher speed = faster sine wave = larger phase increment
            // sweep_speed is in Hz/ms, but for sine sweep we use direct scaling
            sine_phase_inc <= {3'b0, sweep_speed[12:0]} >> 2;
        end else begin
            sine_phase <= 12'd0;
        end
    end
    
    // Convert sine output to signed offset
    // sine_value is 12-bit unsigned (0 to 4095, with 2048 being zero crossing)
    wire signed [12:0] sine_centered;
    assign sine_centered = $signed({1'b0, sine_value}) - 13'sd2048;
    
    // Scale sine to sweep range
    // sine_offset = (sine_centered * sweep_range) / 2048
    wire signed [29:0] sine_scaled;
    assign sine_scaled = sine_centered * $signed({1'b0, sweep_range});
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_offset <= 18'sd0;
        end else begin
            sine_offset <= sine_scaled[28:11];  // Divide by 2048
        end
    end
    
    // =========================================================================
    // Output Frequency Calculation
    // =========================================================================
    wire signed [20:0] freq_with_offset;
    reg signed [17:0] active_offset;
    
    always @(*) begin
        case (sweep_mode)
            2'b00:   active_offset = 18'sd0;           // No sweep
            2'b01:   active_offset = linear_offset;    // Linear sweep
            2'b10:   active_offset = sine_offset;      // Sinusoidal sweep
            default: active_offset = 18'sd0;
        endcase
    end
    
    assign freq_with_offset = $signed({1'b0, base_freq}) + active_offset;
    
    // Clamp output frequency to valid range (1kHz to 999kHz)
    // In pulse mode, output fixed 3 MHz frequency
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_freq <= 20'd100000;  // Default 100kHz
        end else begin
            if (pulse_mode) begin
                current_freq <= 20'd3000000;  // Fixed 3 MHz in pulse mode
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
// Smaller LUT for sweep trajectory
// =============================================================================
module sine_lut_sweep (
    input  wire        clk,
    input  wire [11:0] phase,
    output reg  [11:0] sine_out
);

    // 256-entry quarter sine table (stores 0 to pi/2)
    reg [11:0] quarter_sine [0:255];
    
    // Initialize quarter sine table
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            // sin(i * pi / 512) scaled to 0-2047
            quarter_sine[i] = 2048 + $rtoi(2047.0 * $sin(3.14159265359 * i / 512.0));
        end
    end
    
    // Full sine wave reconstruction from quarter table
    wire [1:0]  quadrant;
    wire [7:0]  index;
    wire [7:0]  table_addr;
    reg  [11:0] table_value;
    
    assign quadrant = phase[11:10];
    assign index = phase[9:2];
    
    // Address manipulation for different quadrants
    assign table_addr = (quadrant[0]) ? (8'd255 - index) : index;
    
    always @(posedge clk) begin
        table_value <= quarter_sine[table_addr];
    end
    
    // Quadrant adjustment
    always @(posedge clk) begin
        case (quadrant)
            2'b00: sine_out <= table_value;                      // 0 to pi/2
            2'b01: sine_out <= table_value;                      // pi/2 to pi
            2'b10: sine_out <= 12'd4095 - table_value;           // pi to 3pi/2
            2'b11: sine_out <= 12'd4095 - table_value;           // 3pi/2 to 2pi
        endcase
    end

endmodule
