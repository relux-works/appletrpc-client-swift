import Foundation

/// APDU command (C-APDU) builder.
///
/// Models the ISO 7816-4 command APDU structure and serializes it into raw bytes
/// for transmission over any ``APDUTransport``.
///
/// Wire format: `[CLA, INS, P1, P2, (Lc, Data...), (Le)]`
///
/// ```swift
/// // SELECT applet by AID
/// let select = APDUCommand(cla: 0x00, ins: 0xA4, p1: 0x04, data: aidBytes)
///
/// // Custom command with P1 parameter
/// let inc = APDUCommand(cla: 0xB0, ins: 0x01, p1: 5)
/// ```
public struct APDUCommand: Sendable {

    /// Class byte — identifies the command category.
    /// Standard ISO commands use `0x00`; applet-specific commands typically use a custom CLA (e.g. `0xB0`).
    public let cla: UInt8

    /// Instruction byte — identifies the specific operation within the CLA class.
    /// For example, `0xA4` = SELECT, `0x01` = first custom command, etc.
    public let ins: UInt8

    /// Parameter byte 1 — instruction-dependent. Often carries a single `u8` argument
    /// (e.g. increment amount) or addressing mode flags.
    public let p1: UInt8

    /// Parameter byte 2 — instruction-dependent. Often unused (`0x00`) or carries
    /// a second `u8` argument.
    public let p2: UInt8

    /// Command data field (optional). Variable-length payload sent to the card.
    /// When present, the Lc byte (data length) is prepended automatically during serialization.
    public let data: Data?

    /// Expected response length (optional). Tells the card how many bytes the client expects back.
    /// When present, appended as the final byte of the serialized command.
    public let le: UInt8?

    /// Create an APDU command.
    ///
    /// - Parameters:
    ///   - cla: Class byte (e.g. `0x00` for ISO, `0xB0` for custom applet commands).
    ///   - ins: Instruction byte identifying the operation.
    ///   - p1: Parameter 1, defaults to `0x00`.
    ///   - p2: Parameter 2, defaults to `0x00`.
    ///   - data: Optional command data payload. Lc is derived automatically from `data.count`.
    ///   - le: Optional expected response length byte.
    public init(cla: UInt8, ins: UInt8, p1: UInt8 = 0x00, p2: UInt8 = 0x00, data: Data? = nil, le: UInt8? = nil) {
        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
        self.data = data
        self.le = le
    }

    /// Serialized command APDU bytes ready for transmission.
    ///
    /// Layout: `[CLA, INS, P1, P2]` + optional `[Lc, Data...]` + optional `[Le]`
    public var bytes: Data {
        var buf = Data([cla, ins, p1, p2])
        if let data, !data.isEmpty {
            buf.append(UInt8(data.count))
            buf.append(data)
        }
        if let le {
            buf.append(le)
        }
        return buf
    }
}
