const micro = @import("microzig");

// this will instantiate microzig and pull in all dependencies
pub const panic = micro.panic;

const pins =
    switch (micro.config.chip_name) {
    .@"ATmega328p" => .{
        .uart_tx = micro.Pin("PB5"),
        .uart_rx = micro.Pin("PB5"),
        .led = micro.Pin("PB5"),
    },
    .@"NXP LPC1768" => .{
        .uart_tx = micro.Pin("P0.15"),
        .uart_rx = micro.Pin("P0.16"),
        .led = micro.Pin("P0.18"),
    },
    .@"Raspberry Pi RP2040" => .{
        .uart_tx = micro.Pin("GPIO0"),
        .uart_rx = micro.Pin("GPIO1"),
        .led = micro.Pin("GPIO25"),
    },
    else => @compileError("unknown chip"),
};

pub const cpu_frequency: u32 = 100_000_000; // 100 MHz

//
//const PLL = struct {
//    fn init() void {
//        reset_overclocking();
//    }
//
//    fn reset_overclocking() void {
//        overclock_flash(5); // 5 cycles access time
//        overclock_pll(3); // 100 MHz
//    }
//
//    fn overclock_flash(timing: u5) void {
//        micro.chip.registers.SYSCON.FLASHCFG.write(.{
//            .FLASHTIM = @intToEnum(@TypeOf(micro.chip.registers.SYSCON.FLASHCFG.read().FLASHTIM), @intCast(u4, timing - 1)),
//        });
//    }
//    fn feed_pll() callconv(.Inline) void {
//        micro.chip.registers.SYSCON.PLL0FEED.write(.{ .PLL0FEED = 0xAA });
//        micro.chip.registers.SYSCON.PLL0FEED.write(.{ .PLL0FEED = 0x55 });
//    }
//
//    fn overclock_pll(divider: u8) void {
//        // PLL einrichten für RC
//        micro.chip.registers.SYSCON.PLL0CON.write(.{
//            .PLLE0 = 0,
//            .PLLC0 = 0,
//        });
//        feed_pll();
//
//        micro.chip.registers.SYSCON.CLKSRCSEL.write(.{ .CLKSRC = .SELECTS_THE_INTERNAL }); // RC-Oszillator als Quelle
//        micro.chip.registers.SYSCON.PLL0CFG.write(.{
//            // SysClk = (4MHz / 2) * (2 * 75) = 300 MHz
//            .MSEL0 = 74,
//            .NSEL0 = 1,
//        });
//        // CPU Takt = SysClk / divider
//        micro.chip.registers.SYSCON.CCLKCFG.write(.{ .CCLKSEL = divider - 1 });
//
//        feed_pll();
//
//        micro.chip.registers.SYSCON.PLL0CON.modify(.{ .PLLE0 = 1 }); // PLL einschalten
//        feed_pll();
//
//        var i: usize = 0;
//        while (i < 1_000) : (i += 1) {
//            micro.cpu.nop();
//        }
//
//        micro.chip.registers.SYSCON.PLL0CON.modify(.{ .PLLC0 = 1 });
//        feed_pll();
//    }
//};

pub fn main() !void {
    micro.reset(.{.gpio});

    pins.led.route(.gpio);
    pins.uart_tx.route(.uart0_tx);
    pins.uart_rx.route(.uart0_rx);

    const gpio_init = .{ .mode = .output, .initial_state = .low };

    const led1 = micro.Gpio(pins.led, gpio_init);
    led1.init();

    var debug_port = micro.Uart(0).init(.{
        .baud_rate = 9600,
        .stop_bits = .one,
        .parity = null,
        .data_bits = .eight,
    }) catch |err| {
        led1.write(.high);

        micro.hang();
    };

    var out = debug_port.writer();
    var in = debug_port.reader();

    try out.writeAll("Please enter a sentence:\r\n");

    while (true) {
        try out.writeAll(".");
        micro.debug.busySleep(100_000);
    }
}
