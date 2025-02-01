
const std = @import("std");

pub fn NullSentinelArray(comptime T: type, len: usize) type {
    return struct {
        const Self = @This();
        data: [len:null]?T,
        max: usize = len,

        pub const ArrayError = error{
            IndexOutOfBounds,
            ArrayFull,
            ItemNotPresent,
        };

        pub fn new() Self {
            return Self{.data = .{null} ** len,
            };
        }

        pub fn num_left(self: *const Self) usize {
            inline for (self.data, 0..) |elem, count| {
                if (elem == null) return count;
            }
            return len;
        }

        /// Pushes `item` into the array. Throws `ArrayFull` if it is full.
        /// You can push `null` safely if array is full.
        pub fn push(self: *Self, item: ?T) ArrayError!void {
            if (item == null) return;
            const num = self.num_left();
            if (num >= len) return ArrayError.ArrayFull;
            self.data[num] = item;
        }

        /// Sets last element in array to `null`
        /// Returns the last element in the array (which can be null or `T`).
        pub fn pop(self: *Self) ?T {
            const n_left = self.num_left();
            if (n_left == 0) return null;
            const old: ?T = self.data[n_left-1];
            self.data[n_left-1] = null;
            return old;
        }

        /// Return a copy of the element at `ind`. null if out of bounds or `ind` is null
        pub fn get(self: *const Self, ind: usize) ?T {
            if (ind >= len) return null;
            return self.data[ind];
        }

        /// Remove the given element and shift all others to the left.
        /// Returns `ItemNotPresent` if the item is not there.
        pub fn remove(self: *Self, item: T) ArrayError!void {
            const found_ind = try self.find(item);

            self.remove_ind(found_ind);
        }

        /// Remove the element at `ind` and shift all others to the left.
        /// Will work if `ind` is not inside of the array or points to a null inside of the array.  
        /// This is because to me a null sentinel array means after the last element you can imagine an infinity of nulls stretching into the distance
        pub fn remove_ind(self: *Self, ind: usize) void {
            if (ind >= len) return;
            self.data[ind] = null;
            for ((ind+1)..len) |indd| {
                if (self.data[indd] == null) break;
                self.data[indd-1] = self.data[indd];
                self.data[indd] = null;
            }
        }

        /// Returns the index of `item` in the array or `ItemNotPresent` if it can't be found
        pub fn find(self: *const Self, item: T) ArrayError!usize {
            for(0..len) |ind| {
                if (self.data[ind] != null and std.meta.eql(self.data[ind].?, item)) {
                    return ind;
                }
            }
            return ArrayError.ItemNotPresent;
        }
    };

}


test "u8 array" {
    const expect = @import("std").testing.expect;

    var bob = NullSentinelArray(u8, 5).new();
    try expect(bob.num_left() == 0);


}