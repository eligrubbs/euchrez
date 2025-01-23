// Helpful functions


// copied from https://github.com/ziglang/zig/issues/15556#issuecomment-1532496771
pub fn enumFieldRange(comptime E: type, comptime firstVal: E, comptime lastVal: E) []const E {
    const fields = @typeInfo(E).Enum.fields; 

    comptime var start_index: usize = 0;
    comptime var end_index: usize = 0;

    inline for(fields, 0..) |f, i| {
        const val: E = @enumFromInt(f.value);
        if (val == firstVal) start_index = i;
        if (val == lastVal) end_index = i;
    }

    comptime var enumArray: [end_index-start_index+1]E = undefined;
    inline for(&enumArray, fields[start_index..end_index+1]) |*e, f| {
        e.* = @enumFromInt(f.value);
    }

    return &enumArray;
}