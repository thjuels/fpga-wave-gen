# Arbitrary Waveform Generator (AWG) - FPGA Implementation

## Target Platform
- **FPGA**: Xilinx XC7A35T-ICPG236C
- **Board**: Digilent Basys3
- **System Clock**: 100 MHz

## Project Overview

This project implements an arbitrary waveform generator capable of producing:
- Sine waves
- Sawtooth waves
- Triangle waves
- Square/pulse waves with adjustable duty cycle

### Features

#### Basic Requirements
1. **Data Input Processing**
   - Button-based frequency adjustment
   - Switch-based waveform selection
   - 4-digit 7-segment display showing frequency
   - Phase configuration (precision: 2π/1000, default: 0)

2. **Waveform Generation**
   - Frequency range: 1 kHz to 999 kHz (1 kHz stride)
   - All four waveform types supported
   - DDS (Direct Digital Synthesis) architecture

3. **Frequency Sweeping**
   - Linear sweeping: Triangular trajectory, ±20 kHz deviation
   - Sinusoidal sweeping: Sine curve trajectory, ±20 kHz deviation
   - Maximum sweep rate: 1 kHz/μs

4. **Duty Cycle (Square Wave)**
   - Fixed modes: 1/2, 1/3, 1/4, 1/7
   - MHz pulse output (frequency = average of student ID last digits)

#### Expansion Requirements
1. **Configurable Sweep Parameters**
   - Sweep range: Configurable up to ±50 kHz
   - Sweep speed: Configurable up to ±4 kHz/ms

2. **Continuous Duty Cycle**
   - Adjustable from 1% to 99%
   - 1% stride resolution

3. **Fine Frequency Control**
   - 1 Hz stride (switchable from 1 kHz stride)
   - Full range: 1 kHz to 999 kHz

## File Structure

```
awg_project/
├── awg_top.v              # Top-level module
├── button_debounce.v      # Button debouncing
├── input_processor.v      # User input handling
├── sweep_controller.v     # Frequency sweep logic
├── phase_accumulator.v    # NCO/DDS core
├── sine_generator.v       # Sine wave LUT
├── sawtooth_generator.v   # Sawtooth generator
├── triangle_generator.v   # Triangle generator
├── square_generator.v     # Square/pulse generator
├── seven_seg_controller.v # 7-segment display driver
├── pulse_generator_mhz.v  # MHz pulse generator
├── ila_debug.v            # ILA debug wrapper
├── basys3_constraints.xdc # Pin constraints
├── awg_testbench.v        # Simulation testbench
├── create_project.tcl     # Vivado project script
└── README.md              # This file
```

## Pin Assignments

### Switches
| Pin  | Signal         | Function                    |
|------|----------------|-----------------------------|
| SW0  | sw_waveform[0] | Waveform select bit 0       |
| SW1  | sw_waveform[1] | Waveform select bit 1       |
| SW2  | sw_sweep_mode[0] | Sweep mode bit 0          |
| SW3  | sw_sweep_mode[1] | Sweep mode bit 1          |
| SW4  | sw_duty_sel[0] | Duty cycle select bit 0     |
| SW5  | sw_duty_sel[1] | Duty cycle select bit 1     |
| SW6  | sw_phase_mode  | Phase configuration mode    |
| SW7  | sw_cont_duty   | Continuous duty mode        |
| SW8  | sw_cont_freq   | 1 Hz stride mode            |

### Waveform Selection (SW1:SW0)
| SW1 | SW0 | Waveform  |
|-----|-----|-----------|
|  0  |  0  | Sine      |
|  0  |  1  | Sawtooth  |
|  1  |  0  | Triangle  |
|  1  |  1  | Square    |

### Sweep Mode (SW3:SW2)
| SW3 | SW2 | Mode        |
|-----|-----|-------------|
|  0  |  0  | No sweep    |
|  0  |  1  | Linear      |
|  1  |  0  | Sinusoidal  |

### Duty Cycle (SW5:SW4)
| SW5 | SW4 | Duty Cycle |
|-----|-----|------------|
|  0  |  0  | 1/2 (50%)  |
|  0  |  1  | 1/3 (33%)  |
|  1  |  0  | 1/4 (25%)  |
|  1  |  1  | 1/7 (14%)  |

### Buttons
| Button  | Function                           |
|---------|-------------------------------------|
| BTNU    | Increase value                      |
| BTND    | Decrease value                      |
| BTNL    | Select previous digit / mode        |
| BTNR    | Select next digit / mode            |
| BTNC    | Confirm / cycle configuration mode  |

### DAC Output
- **Pmod JA**: DAC bits [7:0]
- **Pmod JB**: DAC bits [11:8]
- Connect to external 12-bit DAC or use R-2R ladder

## Usage Instructions

### Building the Project

1. **Using TCL Script**:
   ```tcl
   cd <project_directory>
   vivado -mode batch -source create_project.tcl
   ```

2. **Manual Vivado Setup**:
   - Create new project targeting XC7A35TCPG236-1
   - Add all .v source files
   - Add constraints file (.xdc)
   - Run synthesis and implementation
   - Generate bitstream

### Operation

1. **Power on** the Basys3 board
2. **Select waveform** using SW1:SW0
3. **Set frequency** using buttons:
   - Use BTNL/BTNR to select digit position
   - Use BTNU/BTND to adjust value
4. **Configure phase** (optional):
   - Enable SW6 for phase mode
   - Adjust using BTNU/BTND
5. **Enable sweep** (optional):
   - Set SW3:SW2 for desired sweep mode
   - Press BTNC to access sweep parameters
6. **View output**:
   - Connect oscilloscope to Pmod JA/JB
   - Or use ILA in Vivado for digital capture

### Viewing Waveforms with ILA

1. Uncomment ILA instantiation in `ila_debug.v`
2. Uncomment ILA generation in `create_project.tcl`
3. Rebuild project
4. Program FPGA
5. Open Hardware Manager
6. Add ILA dashboard
7. Set trigger and capture

## Technical Details

### DDS Architecture
The waveform generator uses Direct Digital Synthesis:
- 32-bit phase accumulator
- Phase increment = (freq × 2³²) / 100MHz
- Output samples from 12-bit lookup tables

### Frequency Accuracy
- Phase increment approximation: freq × 43 (with correction)
- Typical accuracy: < 0.5% error
- Jitter: < 1 LSB on phase accumulator

### Timing
- All logic synchronized to 100 MHz clock
- Button debounce: 10 ms
- Display refresh: ~1 kHz per digit

## Customization

### Changing MHz Pulse Frequency
Edit `pulse_generator_mhz.v`:
```verilog
parameter N_MHZ = 5  // Change to your value
```

### Adjusting Sweep Parameters
Modify defaults in `input_processor.v`:
```verilog
localparam DEFAULT_SWEEP_RANGE = 17'd20000;  // Hz
localparam DEFAULT_SWEEP_SPEED = 13'd1000;   // Hz/ms
```

## Known Limitations

1. DAC output requires external DAC module
2. Maximum frequency limited by 100 MHz clock
3. Sine LUT uses ~4KB of BRAM

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No output | Check RST button, verify constraints |
| Garbled display | Check 7-seg connections |
| Wrong frequency | Verify clock input (100 MHz) |
| Sweep not working | Ensure sweep mode switches set |

## License
Educational use for FPGA course final project.
