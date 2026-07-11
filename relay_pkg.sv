package relay_pkg;

// DATA WIDTHS MUST BE BYTE ALIGNED
localparam int BUFFER_SIZE = 64;
localparam int INDEX_SIZE = $clog2(BUFFER_SIZE);
localparam int ADC_DW = 16;
localparam int ADC_OFFSET = 0; // 2**(ADC_DW-1);
localparam int ACC_DW = 24;
localparam int MAG_DW = 2*ACC_DW;
localparam COS_PATH = "./resources/rom_cos.hex";
localparam SIN_PATH = "./resources/rom_sin.hex";

localparam int FUNDAMENTAL_F = 60; // in Hz
localparam int SAMPLING_F = FUNDAMENTAL_F * BUFFER_SIZE;
localparam int AMP_NOMINAL = 311 * BUFFER_SIZE / 2;

localparam real A27_INTERVAL = 0.5; // in s
localparam int A27_TIMEOUT = int'(A27_INTERVAL * SAMPLING_F);
localparam int A27_THRESHOLD = int'(AMP_NOMINAL * 0.8);
localparam int A27_HYSTERESIS = int'(A27_THRESHOLD * 0.00);

localparam real A59_INTERVAL = 0.5; // in s
localparam int A59_TIMEOUT = int'(A59_INTERVAL * SAMPLING_F);
localparam int A59_PICKUP = int'(AMP_NOMINAL * 1.2);
localparam int A59_HYSTERESIS = int'(A59_PICKUP * 0.00);

localparam int MAIN_CLK = 50_000_000;
localparam int DIVIDER_FACTOR = MAIN_CLK / SAMPLING_F;
localparam int DIVIDER_SIZE = $clog2(DIVIDER_FACTOR);

localparam int FIFO_DEPTH = 1024;
localparam int FIFO_INDEX = $clog2(FIFO_DEPTH);

localparam real DEBOUNCER_TIME = 0.02; // in s
localparam int DEBOUNCER_LIMIT = int'(MAIN_CLK * DEBOUNCER_TIME);

endpackage