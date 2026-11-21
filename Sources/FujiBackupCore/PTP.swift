import Foundation

/// The few PTP (ISO 15740) pieces this app uses. All fields are little-endian.
public enum PTP {
    public enum Op: UInt16, Sendable {
        case getDeviceInfo = 0x1001
        case getObjectInfo = 0x1008
        case getObject = 0x1009
        case sendObjectInfo = 0x100C
        case sendObject = 0x100D
        case getDevicePropValue = 0x1015
    }

    public static let responseOK: UInt16 = 0x2001

    /// Fujifilm's USB mode property. 6 = USB RAW CONV./BACKUP RESTORE.
    public static let fujiUSBModeProperty: UInt32 = 0xD16E
    public static let fujiUSBModeBackupRestore = 6

    /// A command container: length, type 1 (command), operation code, transaction id, parameters.
    public static func command(_ op: Op, transaction: UInt32, params: [UInt32] = []) -> Data {
        var w = ByteWriter()
        w.u32(UInt32(12 + 4 * params.count))
        w.u16(1)
        w.u16(op.rawValue)
        w.u32(transaction)
        params.forEach { w.u32($0) }
        return w.data
    }

    /// The response code from a response container (type 3). Nil if it isn't one.
    public static func responseCode(_ container: Data) -> UInt16? {
        var r = ByteReader(container)
        guard let length = r.u32(), length >= 12, let type = r.u16(), type == 3, let code = r.u16() else { return nil }
        return code
    }

    /// The data phase without its container header, if the framework left one on.
    public static func payload(_ data: Data) -> Data {
        var r = ByteReader(data)
        if data.count >= 12, let length = r.u32(), length == data.count, let type = r.u16(), type == 2 {
            return data.subdata(in: data.startIndex + 12 ..< data.endIndex)
        }
        return data
    }

    /// The ObjectInfo dataset sent before a settings restore: format 0x5000 and the file's size, zero-padded
    /// to 1076 bytes, the length Fujifilm's own app sends.
    public static func backupObjectInfo(size: Int) -> Data {
        var w = ByteWriter()
        w.u32(0)                 // StorageID
        w.u16(0x5000)            // ObjectFormat
        w.u16(0)                 // ProtectionStatus
        w.u32(UInt32(size))      // ObjectCompressedSize
        var d = w.data
        d.append(Data(count: 1076 - d.count))
        return d
    }

    /// A device property value as an unsigned integer (1, 2 or 4 bytes).
    public static func integerValue(_ data: Data) -> Int? {
        var r = ByteReader(data)
        switch data.count {
        case 1: return r.u8().map(Int.init)
        case 2: return r.u16().map(Int.init)
        case 4...: return r.u32().map(Int.init)
        default: return nil
        }
    }
}

/// The parts of the PTP DeviceInfo dataset this app shows.
public struct DeviceInfo: Equatable, Sendable {
    public var manufacturer: String
    public var model: String
    public var firmware: String
    public var serial: String

    public init(manufacturer: String, model: String, firmware: String, serial: String) {
        self.manufacturer = manufacturer; self.model = model; self.firmware = firmware; self.serial = serial
    }

    public init?(_ data: Data) {
        var r = ByteReader(data)
        guard r.u16() != nil, r.u32() != nil, r.u16() != nil, r.string() != nil, r.u16() != nil else { return nil }
        for _ in 0..<5 { guard r.u16Array() != nil else { return nil } }   // operations, events, properties, capture and image formats
        guard let m = r.string(), let model = r.string(), let fw = r.string(), let serial = r.string() else { return nil }
        self.init(manufacturer: m, model: model, firmware: fw, serial: serial)
    }
}

struct ByteWriter {
    var data = Data()
    mutating func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    mutating func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    /// A PTP string: character count including the terminator, then UTF-16LE.
    mutating func string(_ s: String) {
        if s.isEmpty { data.append(0); return }
        let units = Array(s.utf16) + [0]
        data.append(UInt8(units.count))
        units.forEach { u16($0) }
    }
}

struct ByteReader {
    private let bytes: [UInt8]
    private var at = 0
    init(_ data: Data) { bytes = [UInt8](data) }

    mutating func u8() -> UInt8? {
        guard at < bytes.count else { return nil }
        defer { at += 1 }
        return bytes[at]
    }
    mutating func u16() -> UInt16? {
        guard at + 2 <= bytes.count else { return nil }
        defer { at += 2 }
        return UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8
    }
    mutating func u32() -> UInt32? {
        guard let lo = u16(), let hi = u16() else { return nil }
        return UInt32(lo) | UInt32(hi) << 16
    }
    mutating func u16Array() -> [UInt16]? {
        guard let n = u32(), at + Int(n) * 2 <= bytes.count else { return nil }
        return (0..<n).compactMap { _ in u16() }
    }
    mutating func string() -> String? {
        guard let n = u8() else { return nil }
        if n == 0 { return "" }
        var units: [UInt16] = []
        for _ in 0..<n { guard let u = u16() else { return nil }; units.append(u) }
        if units.last == 0 { units.removeLast() }
        return String(decoding: units, as: UTF16.self)
    }
}
