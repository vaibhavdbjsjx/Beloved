/// Deterministic 64-bit FNV-1a hash.
///
/// Swift's `Hasher` is randomly seeded per process, so it cannot be used for anything
/// that must be stable across launches (e.g. "the same prayer all day" rotation).
public enum StableHash {
    public static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
