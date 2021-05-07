const std = @import("std");
const micro = @import("microzig.zig");
const chip = @import("chip");

fn SpiIo(comptime Self: type) type {
    return struct {
        pub fn canRead(self: Self) bool {
            return self.internal.canRead();
        }

        pub fn canWrite(self: Self) bool {
            return self.internal.canWrite();
        }

        pub fn reader(self: Self) Reader {
            return Reader{ .context = self };
        }

        pub fn writer(self: Self) Writer {
            return Writer{ .context = self };
        }

        pub const Reader = std.io.Reader(Self, ReadError, readSome);
        pub const Writer = std.io.Writer(Self, WriteError, writeSome);

        fn readSome(self: Self, buffer: []u8) ReadError!usize {
            for (buffer) |*c| {
                c.* = self.internal.rx();
            }
            return buffer.len;
        }
        fn writeSome(self: Self, buffer: []const u8) WriteError!usize {
            for (buffer) |c| {
                self.internal.tx(c);
            }
            return buffer.len;
        }
    };
}

fn SpiDevice(Spi_: anytype, pin_: anytype) type {
    const cs_gpio_ = micro.Gpio(pin_, .{ .mode = .output, .initial_state = .low });

    return struct {
        const Self = @This();

        internal: Spi_,

        const cs_gpio = cs_gpio_;

        pub fn init() void {
            cs_gpio.init();
        }

        pub fn start(self: Self) void {
            cs_gpio.write(.high);
        }
        pub fn stop(self: Self) void {
            cs_gpio.write(.low);
        }

        pub usingnamespace SpiIo(Self);
    };
}

pub fn Spi(comptime index: usize, comptime devices: anytype) type {
    const SystemSpi = chip.Spi(index);

    // contains mapping field index -> SpiDevice type
    var device_mapper: []const type = &[_]type{};

    inline for (std.meta.fields(@TypeOf(devices))) |field, i| {
        device_mapper = device_mapper ++ &[_]type{SpiDevice(SystemSpi, @field(devices, field.name))};
    }

    return struct {
        const Self = @This();

        internal: SystemSpi,

        /// Initializes the Spi with the given config and returns a handle to the Spi.
        pub fn init(config: Config) InitError!Self {
            inline for (device_mapper) |device_| {
                device_.init();
            }

            return Self{
                .internal = try SystemSpi.init(config),
            };
        }

        fn deviceType(dev: anytype) type {
            return device_mapper[std.meta.fieldIndex(@TypeOf(devices), @tagName(dev)).?];
        }

        pub fn device(self: Self, dev: anytype) deviceType(dev) {
            return .{
                .internal = self.internal,
            };
        }

        pub usingnamespace SpiIo(Self);
    };
}

/// A UART configuration. The config defaults to the *8N1* setting, so "8 data bits, no parity, 1 stop bit" which is the 
/// most common serial format.
pub const Config = struct {
    baud_rate: u32,
    data_bits: DataBits = .eight,
    endianess: std.builtin.Endian,
};

// TODO: comptime verify that the enums are valid
pub const DataBits = chip.spi.DataBits;
pub const Polarity = enum {};

pub const InitError = error{
    UnsupportedWordSize,
    UnsupportedParity,
    UnsupportedStopBitCount,
    UnsupportedBaudRate,
};

pub const ReadError = error{
    /// The input buffer received a byte while the receive fifo is already full.
    /// Devices with no fifo fill overrun as soon as a second byte arrives.
    Overrun,
    /// A byte with an invalid parity bit was received.
    ParityError,
    /// The stop bit of our byte was not valid.
    FramingError,
    /// The break interrupt error will happen when RXD is logic zero for
    /// the duration of a full byte.
    BreakInterrupt,
};
pub const WriteError = error{};
