import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// TCP transport for the javacard-rpc bridge.
///
/// Connects to a running bridge server over TCP and forwards APDUs using the
/// bridge binary framing protocol:
/// ```
/// [2B big-endian payload length] [1B message type] [payload bytes...]
/// ```
///
/// Uses POSIX sockets for reliable blocking I/O (no RunLoop dependency).
///
/// ```swift
/// let transport = TCPTransport(host: "127.0.0.1", port: 9025)
/// try transport.connect()
/// defer { transport.disconnect() }
///
/// let client = CounterClient(transport: transport)
/// let value = try await client.increment(amount: 5)
/// ```
///
/// - Note: This transport is intended for development and testing only.
///   For production, implement ``APDUTransport`` over CoreBluetooth or NFC.
public final class TCPTransport: APDUTransport, @unchecked Sendable {

    private let host: String
    private let port: UInt16
    private var fd: Int32 = -1

    /// Create a TCP transport targeting the given bridge address.
    ///
    /// - Parameters:
    ///   - host: Bridge server hostname or IP. Defaults to `"127.0.0.1"`.
    ///   - port: Bridge server TCP port. Defaults to `9025`.
    public init(host: String = "127.0.0.1", port: UInt16 = 9025) {
        self.host = host
        self.port = port
    }

    /// Open a TCP connection to the bridge server.
    ///
    /// Must be called before ``transmit(_:)``. Call ``disconnect()`` when done.
    ///
    /// - Throws: ``APDUError/connectionFailed(_:)`` if the socket cannot be created
    ///   or the connection is refused.
    public func connect() throws {
        fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw APDUError.connectionFailed("socket() failed: \(errno)")
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            close(fd)
            fd = -1
            throw APDUError.connectionFailed("Invalid host: \(host)")
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            let err = errno
            close(fd)
            fd = -1
            throw APDUError.connectionFailed("connect() failed: \(err) (\(String(cString: strerror(err))))")
        }
    }

    /// Close the TCP connection.
    ///
    /// Safe to call multiple times or on an already-disconnected transport.
    public func disconnect() {
        if fd >= 0 {
            close(fd)
            fd = -1
        }
    }

    public func transmit(_ command: APDUCommand) async throws -> APDUResponse {
        guard fd >= 0 else {
            throw APDUError.connectionFailed("Not connected")
        }

        // Build frame: [2B len][0x01 APDU][command bytes]
        let cmdBytes = command.bytes
        let payloadLen = UInt16(1 + cmdBytes.count)
        var frame = Data()
        frame.append(UInt8(payloadLen >> 8))
        frame.append(UInt8(payloadLen & 0xFF))
        frame.append(0x01) // message type: APDU
        frame.append(cmdBytes)

        // Send entire frame
        try sendAll(frame)

        // Read response frame
        let lenBuf = try recvExact(2)
        let respLen = Int(UInt16(lenBuf[0]) << 8 | UInt16(lenBuf[1]))
        guard respLen > 0 else {
            throw APDUError.invalidResponse
        }

        let respBuf = try recvExact(respLen)

        // First byte is message type
        guard respBuf[0] == 0x81 else { // APDU_RESPONSE
            if respBuf[0] == 0xE0 { // ERROR
                let msg = respLen > 4 ? String(data: Data(respBuf[4...]), encoding: .utf8) ?? "unknown" : "unknown"
                throw APDUError.connectionFailed("Bridge error: \(msg)")
            }
            throw APDUError.invalidResponse
        }

        // Rest is R-APDU
        let rapdu = Data(respBuf[1...])
        guard rapdu.count >= 2 else {
            throw APDUError.invalidResponse
        }

        return APDUResponse(rawBytes: rapdu)
    }

    // MARK: - Private

    private func sendAll(_ data: Data) throws {
        try data.withUnsafeBytes { bufPtr in
            let ptr = bufPtr.baseAddress!
            var sent = 0
            while sent < data.count {
                let n = send(fd, ptr + sent, data.count - sent, 0)
                guard n > 0 else {
                    throw APDUError.connectionFailed("send() failed: \(errno)")
                }
                sent += n
            }
        }
    }

    private func recvExact(_ count: Int) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: count)
        var received = 0
        while received < count {
            let n = buf.withUnsafeMutableBufferPointer { ptr in
                recv(fd, ptr.baseAddress! + received, count - received, 0)
            }
            guard n > 0 else {
                throw APDUError.invalidResponse
            }
            received += n
        }
        return buf
    }
}
