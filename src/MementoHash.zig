//! MementoHash implementation.

const std = @import("std");

const MementoHash = @This();

const Entry = struct {
    prev_removed: u32,
    replacer: u32,
};

map: std.AutoHashMap(u32, Entry),
b_array_size: u32,
last_removed: u32,

/// Initialize MementoHash engine.
pub fn init(allocator: std.mem.Allocator, size: u32) MementoHash {
    return .{ .map = std.AutoHashMap(u32, Entry).init(allocator), .last_removed = size, .b_array_size = size };
}

/// Deinitialize MementoHash engine.
pub fn deinit(self: *MementoHash) void {
    self.map.deinit();
}

/// Returns the size of the working set.
pub fn getSize(self: MementoHash) u32 {
    return self.b_array_size - self.map.count();
}

/// Returns bucket where given key should be mapped.
pub fn getBucket(self: MementoHash, key: []const u8) u32 {
    var hash = std.hash.XxHash64.hash(0, key);
    var b = jumpHash(hash, self.b_array_size);
    var replacer_opt = self.getReplacer(b);
    var r_opt: ?u32 = undefined;
    while (replacer_opt) |replacer| : (replacer_opt = r_opt) {
        hash = std.hash.XxHash64.hash(@intCast(b), key);
        b = @intCast(hash % @as(u64, replacer));
        r_opt = self.getReplacer(b);
        while (r_opt) |r| : (r_opt = self.getReplacer(b)) {
            if (r < replacer) {
                break;
            }
            b = r;
        }
    }
    return b;
}

/// Adds a new bucket to the engine.
pub fn addBucket(self: *MementoHash) u32 {
    const bucket = self.last_removed;
    self.last_removed = self.restore(bucket);
    self.b_array_size = if (self.b_array_size > bucket) self.b_array_size else bucket + 1;
    return bucket;
}

/// Removes the given bucket from the engine.
pub fn removeBucket(self: *MementoHash, bucket: u32) !void {
    if (self.last_removed == self.b_array_size and bucket == self.b_array_size - 1) {
        self.b_array_size = bucket;
        self.last_removed = bucket;
    }
    self.last_removed = try self.remember(bucket, self.getSize() - 1, self.last_removed);
}

fn jumpHash(key: u64, num_buckets: u32) u32 {
    var new_key = key;
    var b: u64 = 1;
    var j: u64 = 0;
    while (j < num_buckets) {
        b = j;
        new_key = new_key *% 2862933555777941757 +% 1;
        j = @intFromFloat(@as(f64, @floatFromInt(b +% 1)) * (@as(f64, @as(u64, 1) << 31) / @as(f64, @floatFromInt((new_key >> 33) + 1))));
    }
    return @intCast(b);
}

fn remember(self: *MementoHash, bucket: u32, replacer: u32, prev_removed: u32) !u32 {
    try self.map.put(bucket, .{ .prev_removed = prev_removed, .replacer = replacer });
    return bucket;
}

fn restore(self: *MementoHash, bucket: u32) u32 {
    if (self.map.count() == 0) {
        return bucket + 1;
    }
    const entry = self.map.get(bucket).?;
    const restored = entry.prev_removed;
    _ = self.map.remove(bucket);
    return restored;
}

fn getReplacer(self: MementoHash, bucket: u32) ?u32 {
    if (self.map.get(bucket)) |entry| {
        return entry.replacer;
    } else {
        return null;
    }
}
