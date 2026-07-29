/// @desc Returns the effective (diminishing-returns) value of a raw stat.
///       Formula asymptotes toward 2× at infinity; raw 100 → ~133, raw 200 → ~167.
/// @param {real} raw_stat
/// @returns {real}
function scr_effective_stat(raw_stat) {
    return raw_stat * (2 - raw_stat / (raw_stat + 100));
}
