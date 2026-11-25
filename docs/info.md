<!---
This file is used to generate your project datasheet. Please fill in the information below and delete any unused sections.
-->

## How it works

This module implements a finite state machine (FSM) preprocessor designed to condition sensor signals before a microcontroller processes higher-level patterns.

- **Inputs (`ui_in`):**
  - `ui_in[2:0]`: Zone sensor group A (`A1`, `A2`, `A3`).
  - `ui_in[5:3]`: Zone sensor group D (`D1`, `D2`, `D3`).
  - `ui_in[6]`: `ack` signal from the microcontroller to clear `data_ready`.
  - `ui_in[7]`: Unused.
- **FSM & Time Window:**
  - Starts in `ST_IDLE` waiting for any input on group A or group D.
  - Moves to `ST_CAPTURE` and accumulates active signals over a configurable window (`100` clock cycles by default, equal to `10 ms` at a `10 kHz` base clock).
  - Moves to `ST_DONE` to latch the classification results, assert `data_ready`, and return to `ST_IDLE`.
- **Outputs (`uo_out`):**
  - `uo_out[1:0]` (`status`): `00` = no event, `01` = matching A and D in the same zone, `10` = incomplete (only A or only D), `11` = mismatch or conflicting signals.
  - `uo_out[4:2]` (`zone`): one-hot zone indicator (`001`, `010`, `100`) when a matching event is detected.
  - `uo_out[5]` (`event_ok`): `1` when a valid matching event is detected.
  - `uo_out[6]` (`data_ready`): stays `1` when new results are available until `ack` (`ui_in[6]`) is asserted.
  - `uo_out[7]`: Unused (`0`).

## How to test

1. Apply an active-low reset (`rst_n = 0`) for a few clock cycles, then set `rst_n = 1`.
2. Provide a clock signal (`clk`, e.g., `10 kHz` for a `10 ms` window).
3. Assert one or more inputs in `ui_in[2:0]` and/or `ui_in[5:3]` during the capture window.
4. Wait until `uo_out[6]` (`data_ready`) goes high, then read `uo_out[1:0]`, `uo_out[4:2]`, and `uo_out[5]`.
5. Assert `ui_in[6]` (`ack`) to clear `data_ready` for the next reading cycle.

## External hardware

- Sensor signals from groups A and D (up to 3 zones) wired to `ui_in[5:0]`.
- An external microcontroller (MCU) reading `uo_out[6:0]` and driving `ack` on `ui_in[6]`.
