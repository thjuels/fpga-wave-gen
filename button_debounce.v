// =============================================================================
// Button Debounce Module
// Provides clean single-pulse output for button presses
// =============================================================================

module button_debounce (
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,
    output reg  btn_pulse
);

    // Debounce time: ~10ms at 100MHz = 1,000,000 cycles
    parameter DEBOUNCE_COUNT = 1000000;
    
    reg [19:0] counter;
    reg btn_sync1, btn_sync2;  // Synchronizer
    reg btn_stable;
    reg btn_prev;
    
    // Two-stage synchronizer for metastability
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync1 <= 1'b0;
            btn_sync2 <= 1'b0;
        end else begin
            btn_sync1 <= btn_in;
            btn_sync2 <= btn_sync1;
        end
    end
    
    // Debounce counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 20'd0;
            btn_stable <= 1'b0;
        end else begin
            if (btn_sync2 != btn_stable) begin
                if (counter < DEBOUNCE_COUNT) begin
                    counter <= counter + 1'b1;
                end else begin
                    btn_stable <= btn_sync2;
                    counter <= 20'd0;
                end
            end else begin
                counter <= 20'd0;
            end
        end
    end
    
    // Edge detection for single pulse output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_prev <= 1'b0;
            btn_pulse <= 1'b0;
        end else begin
            btn_prev <= btn_stable;
            btn_pulse <= btn_stable & ~btn_prev;  // Rising edge detection
        end
    end

endmodule
