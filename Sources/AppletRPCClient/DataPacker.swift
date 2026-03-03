import Foundation

/// Helper for packing typed fields into APDU command data.
///
/// Used by generated clients to build the data payload for C-APDUs.
///
/// ```swift
/// var packer = DataPacker()
/// packer.packU16(1024)
/// packer.packBool(true)
/// let command = APDUCommand(cla: 0xB0, ins: 0x01, data: packer.data)
/// ```
public struct DataPacker: Sendable {

    /// Accumulated bytes.
    public private(set) var data = Data()

    public init() {}

    /// Append a single unsigned byte.
    public mutating func packU8(_ value: UInt8) {
        data.append(value)
    }

    /// Append a big-endian unsigned 16-bit integer.
    public mutating func packU16(_ value: UInt16) {
        data.append(UInt8(value >> 8))
        data.append(UInt8(value & 0xFF))
    }

    /// Append a big-endian unsigned 32-bit integer.
    public mutating func packU32(_ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    /// Append a boolean as a single byte (`0x01` for `true`, `0x00` for `false`).
    public mutating func packBool(_ value: Bool) {
        data.append(value ? 0x01 : 0x00)
    }

    /// Append raw bytes.
    public mutating func packBytes(_ value: Data) {
        data.append(value)
    }

    /// Append fixed-length bytes, validating the count matches `length`.
    ///
    /// - Throws: ``APDUError/invalidResponse`` if `value.count != length`.
    public mutating func packFixedBytes(_ value: Data, length: Int) throws {
        guard value.count == length else {
            throw APDUError.invalidResponse
        }
        data.append(value)
    }
}
