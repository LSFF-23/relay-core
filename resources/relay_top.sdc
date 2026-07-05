create_clock -name main_clk -period 5.000 [get_ports {clk}]
create_clock -name hps_clk  -period 5.000 [get_ports {clk_hps}]

set_clock_groups -asynchronous -group {main_clk} -group {hps_clk}

set_false_path -from [get_registers {*a59_pickup[*]}] -to [get_registers {*ansi59*}]
set_false_path -from [get_registers {*a59_hysteresis[*]}] -to [get_registers {*ansi59*}]
set_false_path -from [get_registers {*a59_limit[*]}] -to [get_registers {*ansi59*}]

derive_clock_uncertainty