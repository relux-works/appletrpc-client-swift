import Foundation

/// Raw APDU transport abstraction.
///
/// The single integration point between generated client code and the physical (or simulated) card.
/// Implementations handle the wire protocol; generated clients only produce ``APDUCommand`` values
/// and consume ``APDUResponse`` values.
///
/// Provided implementations:
/// - ``TCPTransport`` — connects to the javacard-rpc bridge over TCP (dev/test).
///
/// Bring your own for production:
/// - `BLETransport` — CoreBluetooth to a real Java Card over NFC/BLE.
public protocol APDUTransport: Sendable {

    /// Send a command APDU to the card and wait for the response.
    ///
    /// - Parameter command: The C-APDU to transmit.
    /// - Returns: The R-APDU received from the card (data + status word).
    /// - Throws: ``APDUError`` on connection, timeout, or protocol errors.
    func transmit(_ command: APDUCommand) async throws -> APDUResponse
}
