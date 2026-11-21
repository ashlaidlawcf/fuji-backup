import Foundation
import Testing
@testable import FujiBackupCore

@Suite struct PTPTests {
    @Test func commandContainer() {
        let c = PTP.command(.getObject, transaction: 7, params: [0])
        #expect([UInt8](c) == [16, 0, 0, 0, 1, 0, 0x09, 0x10, 7, 0, 0, 0, 0, 0, 0, 0])
    }

    @Test func responseCode() {
        #expect(PTP.responseCode(Data([12, 0, 0, 0, 3, 0, 0x01, 0x20, 7, 0, 0, 0])) == 0x2001)
        #expect(PTP.responseCode(Data([12, 0, 0, 0, 1, 0, 0x01, 0x20, 7, 0, 0, 0])) == nil)
        #expect(PTP.responseCode(Data([1, 2])) == nil)
    }

    @Test func payloadStripsDataHeader() {
        let body = Data([0xAA, 0xBB])
        let framed = Data([14, 0, 0, 0, 2, 0, 0x09, 0x10, 7, 0, 0, 0]) + body
        #expect(PTP.payload(framed) == body)
        #expect(PTP.payload(body) == body)
    }

    @Test func backupObjectInfo() {
        let d = PTP.backupObjectInfo(size: 33_404)
        #expect(d.count == 1076)
        #expect([UInt8](d.prefix(12)) == [0, 0, 0, 0, 0x00, 0x50, 0, 0, 0x7C, 0x82, 0, 0])
        #expect(d.dropFirst(12).allSatisfy { $0 == 0 })
    }

    @Test func integerValue() {
        #expect(PTP.integerValue(Data([6, 0])) == 6)
        #expect(PTP.integerValue(Data([6])) == 6)
        #expect(PTP.integerValue(Data()) == nil)
    }

    @Test func deviceInfo() throws {
        var w = ByteWriter()
        w.u16(100); w.u32(0xE); w.u16(100); w.string("fujifilm.co.jp: 1.0;"); w.u16(0)
        for list in [[0x1001, 0x1009], [0x4002], [0xD16E], [], [0x3801]] as [[UInt16]] {
            w.u32(UInt32(list.count)); list.forEach { w.u16($0) }
        }
        w.string("FUJIFILM"); w.string("X-T3"); w.string("5.11"); w.string("123ABC")
        let info = try #require(DeviceInfo(w.data))
        #expect(info == DeviceInfo(manufacturer: "FUJIFILM", model: "X-T3", firmware: "5.11", serial: "123ABC"))
        #expect(DeviceInfo(w.data.prefix(20)) == nil)
    }
}

@Suite struct BackupTests {
    static func blob(model: String = "X-T3", size: Int = 33_404) -> Data {
        var d = Data(count: size)
        d.replaceSubrange(0..<8, with: Data("FUJIFILM".utf8))
        let m = Data(model.utf8)
        d.replaceSubrange(0x14..<0x14 + m.count, with: m)
        return d
    }

    @Test func readsModel() throws {
        #expect(try SettingsBackup(Self.blob()).model == "X-T3")
    }

    @Test func rejectsOtherFiles() {
        #expect(throws: BackupError.notABackup) { try SettingsBackup(Data("hello".utf8)) }
        var d = Self.blob(); d[0] = 0x41
        #expect(throws: BackupError.notABackup) { try SettingsBackup(d) }
        #expect(throws: BackupError.notABackup) { try SettingsBackup(Self.blob(model: "")) }
    }

    @Test func restoreChecks() throws {
        let current = try SettingsBackup(Self.blob())
        try SettingsBackup(Self.blob()).checkRestore(onto: current, backupFirmware: "5.11", cameraFirmware: "5.11")
        try SettingsBackup(Self.blob()).checkRestore(onto: current, backupFirmware: nil, cameraFirmware: "5.11")
        #expect(throws: BackupError.otherModel(backup: "X-T4", camera: "X-T3")) {
            try SettingsBackup(Self.blob(model: "X-T4")).checkRestore(onto: current, backupFirmware: nil, cameraFirmware: "5.11")
        }
        #expect(throws: BackupError.otherFirmware(backup: "5.10", camera: "5.11")) {
            try SettingsBackup(Self.blob()).checkRestore(onto: current, backupFirmware: "5.10", cameraFirmware: "5.11")
        }
        #expect(throws: BackupError.otherLayout) {
            try SettingsBackup(Self.blob(size: 5_660)).checkRestore(onto: current, backupFirmware: nil, cameraFirmware: "5.11")
        }
    }

    @Test func names() {
        var c = DateComponents(); c.year = 2026; c.month = 11; c.day = 21; c.hour = 14; c.minute = 30; c.second = 12
        let date = Calendar(identifier: .gregorian).date(from: c)!
        let name = BackupName.make(model: "X-T3", firmware: "5.11", date: date)
        #expect(name == "X-T3 5.11 2026-11-21 143012.dat")
        #expect(BackupName.firmware(in: name) == "5.11")
        #expect(BackupName.firmware(in: "BACKUP.DAT") == nil)
    }
}
