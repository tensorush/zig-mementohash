//! Root benchmark file that evaluates MementoHash according to the following factors:
//!   - Speed: the time the algorithm needs to find the node the given key belongs to.
//!   - Balance: the ability of the algorithm to spread the keys evenly across the cluster nodes.
//!   - Monotonicity: the ability of the algorithm to move the minimum amount of resources when the cluster scales.

const std = @import("std");
const MementoHash = @import("MementoHash.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Memory leak has occurred!");
    };
    const allocator = gpa.allocator();

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const random = prng.random();

    const std_out = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(std_out.writer());
    const writer = buf_writer.writer();

    const num_removals = 20_000;
    const num_keys = 1_000_000;
    const size = 1_000_000;

    var buf: [1024]u8 = undefined;
    var fixed_buf = std.heap.FixedBufferAllocator.init(buf[0..]);
    const args = try std.process.argsAlloc(fixed_buf.allocator());

    if (std.mem.indexOfScalar(u8, args[1], 's')) |_| {
        try benchmarkSpeed(allocator, random, writer, num_keys, size);
    }

    if (std.mem.indexOfScalar(u8, args[1], 'b')) |_| {
        try benchmarkBalance(allocator, random, writer, num_removals, num_keys, size);
    }

    if (std.mem.indexOfScalar(u8, args[1], 'm')) |_| {
        try benchmarkMonotonicity(allocator, random, writer, num_removals, num_keys, size);
    }

    try buf_writer.flush();
}

pub fn benchmarkSpeed(
    allocator: std.mem.Allocator,
    random: std.Random,
    writer: anytype,
    comptime num_keys: usize,
    comptime size: u32,
) !void {
    var memento = MementoHash.init(allocator, size);
    defer memento.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.lap();

    var bucket: u32 = undefined;
    for (0..num_keys) |_| {
        bucket = memento.getBucket(std.mem.asBytes(&random.uintAtMost(u32, std.math.maxInt(u32))));
    }

    try writer.print("Elapsed time: {}\n", .{std.fmt.fmtDuration(timer.read() - start)});
}

pub fn benchmarkBalance(
    allocator: std.mem.Allocator,
    random: std.Random,
    writer: anytype,
    comptime num_removals: usize,
    comptime num_keys: usize,
    comptime size: u32,
) !void {
    var memento = MementoHash.init(allocator, size);
    defer memento.deinit();

    var anchor_absorbed_keys = [1]f64{0.0} ** size;
    var is_valid_buckets = [1]bool{true} ** size;

    var removed: u32 = undefined;
    var i: usize = 0;
    while (i < num_removals) {
        removed = random.uintLessThan(u32, size);
        if (is_valid_buckets[removed]) {
            try memento.removeBucket(removed);
            is_valid_buckets[removed] = false;
            i += 1;
        }
    }

    for (0..num_keys) |_| {
        anchor_absorbed_keys[memento.getBucket(std.mem.asBytes(&random.uintAtMost(u32, std.math.maxInt(u32))))] += 1.0;
    }

    const mean = @as(f64, num_keys) / @as(f64, size - num_removals);
    var load_balance: f64 = 0.0;
    for (0..size) |j| {
        if (is_valid_buckets[j] and load_balance < anchor_absorbed_keys[j] / mean) {
            load_balance = anchor_absorbed_keys[j] / mean;
        }
    }

    try writer.print("Load balance: {d}\n", .{load_balance});
}

pub fn benchmarkMonotonicity(
    allocator: std.mem.Allocator,
    random: std.Random,
    writer: anytype,
    comptime num_removals: usize,
    comptime num_keys: usize,
    comptime size: u32,
) !void {
    var memento = MementoHash.init(allocator, size);
    defer memento.deinit();

    var is_valid_buckets = [1]bool{true} ** size;

    var removed: u32 = undefined;
    var i: usize = 0;
    while (i < num_removals) {
        removed = random.uintLessThan(u32, size);
        if (is_valid_buckets[removed]) {
            try memento.removeBucket(removed);
            is_valid_buckets[removed] = false;
            i += 1;
        }
    }

    var bucket_map = std.AutoHashMapUnmanaged(u32, u32){};
    defer bucket_map.deinit(allocator);

    i = 0;
    while (i < num_keys) {
        const new_bucket = random.uintAtMost(u32, std.math.maxInt(u32));
        if (bucket_map.contains(new_bucket)) {
            continue;
        }
        const old_bucket = memento.getBucket(std.mem.asBytes(&new_bucket));
        try bucket_map.put(allocator, new_bucket, old_bucket);
        if (!is_valid_buckets[old_bucket]) {
            std.debug.print("Crazy bug", .{});
        }
        i += 1;
    }

    var removed_fake: u32 = undefined;
    var removed_true: u32 = undefined;
    while (true) {
        removed_fake = random.uintLessThan(u32, size);
        if (is_valid_buckets[removed_fake]) {
            removed_true = removed_fake;
            try memento.removeBucket(removed_true);
            if (!is_valid_buckets[removed_true]) {
                std.debug.print("Crazy bug", .{});
            }
            is_valid_buckets[removed_true] = false;
            break;
        }
    }

    var bucket_iter = bucket_map.iterator();
    var old_bucket: u32 = undefined;
    var new_bucket: u32 = undefined;
    var num_mis_keys: u32 = 0;
    while (bucket_iter.next()) |entry| {
        old_bucket = entry.value_ptr.*;
        new_bucket = memento.getBucket(std.mem.asBytes(entry.key_ptr));
        if (old_bucket != new_bucket and old_bucket != removed_true) {
            num_mis_keys += 1;
        }
    }

    try writer.print("Number of misplaced keys after removal: {d:.2}%\n", .{@as(f64, @floatFromInt(num_mis_keys)) / @as(f64, @floatFromInt(num_keys)) * 100});

    bucket_iter = bucket_map.iterator();
    is_valid_buckets[memento.addBucket()] = true;
    num_mis_keys = 0;
    while (bucket_iter.next()) |entry| {
        old_bucket = entry.value_ptr.*;
        new_bucket = memento.getBucket(std.mem.asBytes(entry.key_ptr));
        if (old_bucket != new_bucket) {
            num_mis_keys += 1;
        }
    }

    try writer.print("Number of misplaced keys after restoring: {d:.2}%\n", .{@as(f64, @floatFromInt(num_mis_keys)) / @as(f64, @floatFromInt(num_keys)) * 100});
}
