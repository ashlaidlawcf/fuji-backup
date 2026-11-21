import Foundation
import Testing
@testable import FujiBackupCore

@Suite struct CustomSettingsTests {
    /// An X-T3-sized backup whose C1–C7 hold camera defaults, with `edit` applied to slot records.
    static func backup(model: String = "X-T3", edit: (inout [UInt8], (Int) -> Int) -> Void = { _, _ in }) throws -> SettingsBackup {
        var d = [UInt8](BackupTests.blob(model: model))
        let slot = { (n: Int) in 0x7B7C + (n - 1) * 0x100 }
        for n in 1...7 {
            let b = slot(n)
            d[b + 0x26] = 4; d[b + 0x2E] = 0; d[b + 0x32] = 1; d[b + 0x39] = 4; d[b + 0x3A] = 4; d[b + 0x3B] = 4; d[b + 0x3D] = 2
        }
        edit(&d, slot)
        return try SettingsBackup(Data(d))
    }

    @Test func defaults() throws {
        let c = try #require(CustomSettings.read(Self.backup()))
        #expect(c.count == 7)
        #expect(c[4].title == "C5")
        #expect(c[0].rows.map(\.1) == ["PROVIA/Standard", "Off", "Off", "Auto", "DR100", "0", "0", "0", "0", "0"])
    }

    @Test func recipe() throws {
        let c = try #require(CustomSettings.read(Self.backup { d, slot in
            let b = slot(2)
            let name = Array("Gold 200".utf8)
            d.replaceSubrange((b + 0x71)..<(b + 0x71 + name.count), with: name)
            d[b + 0x2E] = 13; d[b + 0x3D] = 1; d[b + 0x3C] = 2
            d[b + 0x0C] = 8; d[b + 0x0D] = 6
            d[b + 0x32] = 3; d[b + 0x3A] = 5; d[b + 0x3B] = 2; d[b + 0x37] = 7; d[b + 0x39] = 6; d[b + 0x26] = 0
        }))[1]
        #expect(c.title == "Gold 200")
        #expect(c.filmSimulation == "Classic Chrome")
        #expect(c.grain == "Weak")
        #expect(c.colorChrome == "Strong")
        #expect(c.whiteBalance == "6300K")
        #expect(c.dynamicRange == "DR400")
        #expect(c.highlight == "−1")
        #expect(c.shadow == "+2")
        #expect(c.color == "−2")
        #expect(c.sharpness == "−2")
        #expect(c.noiseReduction == "−4")
        #expect(c.text.hasPrefix("Gold 200\nFilm Simulation: Classic Chrome\n"))
    }

    @Test func unknownCodesAndModels() throws {
        let c = try #require(CustomSettings.read(Self.backup { d, slot in d[slot(1) + 0x2E] = 20; d[slot(1) + 0x3C] = 5 }))
        #expect(c[0].filmSimulation == "Film code 20")
        #expect(c[0].colorChrome == "Code 5")
        #expect(CustomSettings.read(try Self.backup(model: "X-T4")) == nil)
        #expect(CustomSettings.read(try SettingsBackup(BackupTests.blob(size: 5_660))) == nil)
    }
}
