// =============================================================================
// Testbench for Arbitrary Waveform Generator
// =============================================================================

`timescale 1ns / 1ps

module awg_tb;

    // =========================================================================
    // Testbench Signals
    // =========================================================================
    reg         clk;
    reg         rst_n;
    reg         btn_up, btn_down, btn_left, btn_right, btn_center;
    reg  [1:0]  sw_waveform;
    reg  [1:0]  sw_sweep_mode;
    reg  [1:0]  sw_duty_sel;
    reg         sw_phase_mode;
    reg         sw_cont_duty;
    reg         sw_cont_freq;
    
    wire [6:0]  seg;
    wire [3:0]  an;
    wire        dp;
    wire [11:0] dac_out;
    wire [15:0] led;
    
    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    awg_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_center(btn_center),
        .sw_waveform(sw_waveform),
        .sw_sweep_mode(sw_sweep_mode),
        .sw_duty_sel(sw_duty_sel),
        .sw_phase_mode(sw_phase_mode),
        .sw_cont_duty(sw_cont_duty),
        .sw_cont_freq(sw_cont_freq),
        .seg(seg),
        .an(an),
        .dp(dp),
        .dac_out(dac_out),
        .led(led)
    );
    
    // =========================================================================
    // Clock Generation (100 MHz)
    // =========================================================================
    initial clk = 0;
    always #5 clk = ~clk;  // 10ns period = 100MHz
    
    // =========================================================================
    // Test Stimulus
    // =========================================================================
    initial begin
        // Initialize signals
        rst_n = 0;
        btn_up = 0;
        btn_down = 0;
        btn_left = 0;
        btn_right = 0;
        btn_center = 0;
        sw_waveform = 2'b00;      // Sine wave
        sw_sweep_mode = 2'b00;    // No sweep
        sw_duty_sel = 2'b00;      // 50% duty
        sw_phase_mode = 0;
        sw_cont_duty = 0;
        sw_cont_freq = 0;
        
        // Release reset after 100ns
        #100;
        rst_n = 1;
        
        // =====================================================================
        // Test 1: Sine Wave Generation
        // =====================================================================
        $display("Test 1: Sine Wave at 100kHz");
        sw_waveform = 2'b00;
        #100000;  // 100us
        
        // =====================================================================
        // Test 2: Sawtooth Wave
        // =====================================================================
        $display("Test 2: Sawtooth Wave");
        sw_waveform = 2'b01;
        #100000;
        
        // =====================================================================
        // Test 3: Triangle Wave
        // =====================================================================
        $display("Test 3: Triangle Wave");
        sw_waveform = 2'b10;
        #100000;
        
        // =====================================================================
        // Test 4: Square Wave with different duty cycles
        // =====================================================================
        $display("Test 4: Square Wave - 50% duty");
        sw_waveform = 2'b11;
        sw_duty_sel = 2'b00;  // 50%
        #50000;
        
        $display("Test 4b: Square Wave - 33% duty");
        sw_duty_sel = 2'b01;  // 33%
        #50000;
        
        $display("Test 4c: Square Wave - 25% duty");
        sw_duty_sel = 2'b10;  // 25%
        #50000;
        
        $display("Test 4d: Square Wave - 14% duty");
        sw_duty_sel = 2'b11;  // 14%
        #50000;
        
        // =====================================================================
        // Test 5: Linear Frequency Sweep
        // =====================================================================
        $display("Test 5: Linear Frequency Sweep");
        sw_waveform = 2'b00;  // Back to sine
        sw_sweep_mode = 2'b01;  // Linear sweep
        #500000;  // 500us
        
        // =====================================================================
        // Test 6: Sinusoidal Frequency Sweep
        // =====================================================================
        $display("Test 6: Sinusoidal Frequency Sweep");
        sw_sweep_mode = 2'b10;  // Sinusoidal sweep
        #500000;
        
        // =====================================================================
        // Test 7: Frequency Adjustment via Buttons
        // =====================================================================
        $display("Test 7: Frequency Adjustment");
        sw_sweep_mode = 2'b00;  // No sweep
        
        // Simulate button press (increase frequency)
        #1000;
        btn_up = 1;
        #20;
        btn_up = 0;
        #20000000;  // Wait for debounce (20ms)
        
        // =====================================================================
        // End of Test
        // =====================================================================
        $display("All tests completed");
        #1000;
        $finish;
    end
    
    // =========================================================================
    // Waveform Monitoring
    // =========================================================================
    // Dump waveforms for viewing
    initial begin
        $dumpfile("awg_waveform.vcd");
        $dumpvars(0, awg_tb);
    end
    
    // Monitor DAC output
    integer log_file;
    initial begin
        log_file = $fopen("dac_output.csv", "w");
        $fdisplay(log_file, "time_ns,dac_value");
    end
    
    always @(posedge clk) begin
        if (rst_n) begin
            $fdisplay(log_file, "%0d,%0d", $time, dac_out);
        end
    end

endmodule

// =============================================================================
// Individual Module Testbenches
// =============================================================================

// Sine Generator Testbench
module sine_generator_tb;
    reg         clk;
    reg  [11:0] phase;
    reg  [9:0]  phase_offset;
    wire [11:0] sine_out;
    
    sine_generator uut (
        .clk(clk),
        .phase(phase),
        .phase_offset(phase_offset),
        .sine_out(sine_out)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        phase = 0;
        phase_offset = 0;
        #100;
        
        // Sweep through all phases
        repeat (4096) begin
            #20;
            phase = phase + 1;
        end
        
        $finish;
    end
endmodule

// Phase Accumulator Testbench
module phase_accumulator_tb;
    reg         clk;
    reg         rst_n;
    reg  [19:0] freq_word;
    reg  [9:0]  phase_offset;
    wire [31:0] phase_acc;
    
    phase_accumulator uut (
        .clk(clk),
        .rst_n(rst_n),
        .freq_word(freq_word),
        .phase_offset(phase_offset),
        .phase_acc(phase_acc)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        rst_n = 0;
        freq_word = 20'd100000;  // 100 kHz
        phase_offset = 10'd0;
        
        #100;
        rst_n = 1;
        
        // Run for several cycles
        #100000;  // 100us
        
        // Change frequency
        freq_word = 20'd200000;  // 200 kHz
        #100000;
        
        // Add phase offset
        phase_offset = 10'd500;  // pi offset
        #100000;
        
        $finish;
    end
endmodule
