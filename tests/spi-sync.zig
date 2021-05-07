const micro = @import("microzig");

// this will instantiate microzig and pull in all dependencies
pub const panic = micro.panic;

const pins =
    switch (micro.config.chip_name) {
    .@"ATmega328p" => .{
        .spi_tx = micro.Pin("PB5"),
        .spi_clk = micro.Pin("PB5"),
        .led = micro.Pin("PB5"),
    },
    .@"NXP LPC1768" => .{
        .spi_tx = micro.Pin("P0.15"),
        .spi_clk = micro.Pin("P0.16"),
        .led = micro.Pin("P0.18"),
    },
    .@"Raspberry Pi RP2040" => .{
        .spi_tx = micro.Pin("GPIO19"),
        .spi_clk = micro.Pin("GPIO18"),
        .led = micro.Pin("GPIO25"),
    },
    else => @compileError("unknown chip"),
};

pub fn main() !void {
    micro.reset(.{.gpio});

    pins.led.route(.gpio);
    pins.spi_tx.route(.spi0_mosi);
    pins.spi_clk.route(.spi0_sclk);

    const gpio_init = .{ .mode = .output, .initial_state = .low };

    const led1 = micro.Gpio(pins.led, gpio_init);
    led1.init();

    var spi0 = micro.Spi(0, .{
        .display = micro.Pin("GPIO21"),
    }).init(.{
        .baud_rate = 1_000_000,
        .endianess = .Big,
        .data_bits = .eight,
    }) catch |err| {
        led1.write(.high);

        micro.hang();
    };

    const display_ctx = spi0.device(.display);

    display_ctx.start();
    defer display_ctx.end();

    try display_ctx.writer().writeAll("Please enter a sentence:\r\n");

    while (true) {
        try display_ctx.writer().writeAll(".");
        micro.debug.busySleep(100_000);
    }
}
