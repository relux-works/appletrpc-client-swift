import Foundation

/// APDU response (R-APDU) parser.
///
/// Models the ISO 7816-4 response APDU: optional data bytes followed by a mandatory
/// 2-byte status word (SW1 + SW2). Provides typed readers for common field types.
///
/// Wire format: `[Data...] [SW1] [SW2]`
///
/// ```swift
/// let resp = try await transport.transmit(command)
/// try resp.checkSW()          // throws if SW != 0x9000
/// let value = resp.readU16()  // parse first 2 bytes as big-endian u16
/// ```
public struct APDUResponse: Sendable {

    /// Raw response bytes as received from the card, including trailing SW1 + SW2.
    public let rawBytes: Data

    /// Create a response from raw R-APDU bytes.
    ///
    /// - Parameter rawBytes: Complete response including data and SW. Must be at least 2 bytes (SW only).
    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }

    /// First status byte. Common values: `0x90` (success), `0x69`/`0x6A` (error categories).
    public var sw1: UInt8 {
        rawBytes[rawBytes.count - 2]
    }

    /// Second status byte. Combined with SW1 to form the full status word.
    public var sw2: UInt8 {
        rawBytes[rawBytes.count - 1]
    }

    /// Combined 16-bit status word (`SW1 << 8 | SW2`).
    /// `0x9000` = success. Anything else is an error or warning.
    public var sw: UInt16 {
        (UInt16(sw1) << 8) | UInt16(sw2)
    }

    /// Response data payload (everything except the trailing 2-byte status word).
    /// Empty if the response contains only SW.
    public var data: Data {
        guard rawBytes.count > 2 else { return Data() }
        return rawBytes.prefix(rawBytes.count - 2)
    }

    /// Verify that the status word is `0x9000` (success).
    ///
    /// - Throws: ``APDUError/statusWord(sw1:sw2:)`` if SW is anything other than `0x9000`.
    public func checkSW() throws {
        guard sw == 0x9000 else {
            throw APDUError.statusWord(sw1: sw1, sw2: sw2)
        }
    }

    // MARK: - Typed readers

    /// Read a single unsigned byte from the response data.
    ///
    /// - Parameter offset: Byte offset into ``data``. Defaults to `0`.
    /// - Returns: The `UInt8` value at the given offset.
    public func readU8(at offset: Int = 0) -> UInt8 {
        data[data.startIndex + offset]
    }

    /// Read a big-endian unsigned 16-bit integer from the response data.
    ///
    /// - Parameter offset: Byte offset into ``data`` where the 2-byte value starts. Defaults to `0`.
    /// - Returns: The `UInt16` value decoded from bytes `[offset, offset+1]`.
    public func readU16(at offset: Int = 0) -> UInt16 {
        let hi = UInt16(data[data.startIndex + offset]) << 8
        let lo = UInt16(data[data.startIndex + offset + 1])
        return hi | lo
    }

    /// Read a contiguous byte slice from the response data.
    ///
    /// - Parameters:
    ///   - offset: Byte offset into ``data``. Defaults to `0`.
    ///   - count: Number of bytes to read. Pass `nil` (default) to read from `offset` to end.
    /// - Returns: A `Data` slice of the requested range.
    public func readBytes(at offset: Int = 0, count: Int? = nil) -> Data {
        let start = data.startIndex + offset
        let end = count.map { start + $0 } ?? data.endIndex
        return data[start..<end]
    }
}

/// Errors that can occur during APDU transport or response parsing.
public enum APDUError: Error, Sendable {
    /// The card returned a non-success status word.
    ///
    /// - Parameters:
    ///   - sw1: First status byte (error category).
    ///   - sw2: Second status byte (specific error code).
    case statusWord(sw1: UInt8, sw2: UInt8)

    /// TCP/BLE connection could not be established or was lost.
    ///
    /// - Parameter reason: Human-readable description of the failure.
    case connectionFailed(String)

    /// Transport-level timeout waiting for a response from the card.
    case timeout

    /// The raw bytes received do not form a valid R-APDU (e.g. fewer than 2 bytes).
    case invalidResponse
}

extension APDUError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .statusWord(let sw1, let sw2):
            return String(format: "APDU error: SW=%02X%02X", sw1, sw2)
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .timeout:
            return "APDU transport timeout"
        case .invalidResponse:
            return "Invalid APDU response"
        }
    }
}
