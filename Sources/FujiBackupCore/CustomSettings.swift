import Foundation

/// The recipe saved in one custom setting (C1–C7) of a settings backup.
public struct CustomSetting: Equatable, Sendable, Identifiable {
    public let slot: Int                 // 1...7
    public let name: String              // empty when not named
    public let filmSimulation: String
    public let grain: String
    public let colorChrome: String
    public let whiteBalance: String
    public let dynamicRange: String
    public let highlight: String
    public let shadow: String
    public let color: String
    public let sharpness: String
    public let noiseReduction: String

    public var id: Int { slot }
    public var title: String { name.isEmpty ? "C\(slot)" : name }

    /// The fields in display order, as (label, value).
    public var rows: [(String, String)] {
        [("Film Simulation", filmSimulation), ("Grain Effect", grain), ("Color Chrome Effect", colorChrome),
         ("White Balance", whiteBalance),
         ("Dynamic Range", dynamicRange), ("Highlight", highlight), ("Shadow", shadow), ("Color", color),
         ("Sharpness", sharpness), ("Noise Reduction", noiseReduction)]
    }

    /// The recipe as plain text, for copying.
    public var text: String {
        ([title] + rows.map { "\($0.0): \($0.1)" }).joined(separator: "\n")
    }
}

/// Reads C1–C7 from a settings backup. Only for layouts checked against this camera's firmware:
/// each value's encoding comes from the firmware's own value-name tables or from controlled backups (see README).
public enum CustomSettings {
    /// The custom settings in `backup`, or nil when the app doesn't know this model's layout.
    public static func read(_ backup: SettingsBackup) -> [CustomSetting]? {
        guard let layout = Layout.all[backup.model], backup.data.count == layout.size else { return nil }
        let d = [UInt8](backup.data)
        return (0..<7).map { i in decode(d, at: layout.firstSlot + i * 0x100, slot: i + 1) }
    }

    struct Layout {
        let size: Int
        let firstSlot: Int               // file offset of C1's 256-byte record
        static let all = ["X-T3": Layout(size: 33_404, firstSlot: 0x7B7C)]
    }

    // Offsets within a slot record, as the X-T3 5.11 firmware's custom-setting getter reads them.
    enum Off {
        static let wb = 0x0C, kelvin = 0x0D, noiseReduction = 0x26, film = 0x2E, dynamicRange = 0x32
        static let color = 0x37, sharpness = 0x39, highlight = 0x3A, shadow = 0x3B, colorChrome = 0x3C, grain = 0x3D
        static let name = 0x71, nameLength = 0x1A
    }

    static func decode(_ d: [UInt8], at b: Int, slot: Int) -> CustomSetting {
        let byte = { (o: Int) in Int(d[b + o]) }
        let nameBytes = d[(b + Off.name)..<(b + Off.name + Off.nameLength)].prefix { $0 != 0 }
        return CustomSetting(
            slot: slot,
            name: String(decoding: nameBytes, as: UTF8.self).trimmingCharacters(in: .whitespaces),
            filmSimulation: films[byte(Off.film)] ?? "Film code \(byte(Off.film))",
            grain: grains[byte(Off.grain)] ?? "Code \(byte(Off.grain))",
            colorChrome: chromes[byte(Off.colorChrome)] ?? "Code \(byte(Off.colorChrome))",
            whiteBalance: whiteBalance(byte(Off.wb), kelvin: byte(Off.kelvin)),
            dynamicRange: dynamicRanges[byte(Off.dynamicRange)] ?? "Code \(byte(Off.dynamicRange))",
            highlight: signed(4 - byte(Off.highlight)),
            shadow: signed(4 - byte(Off.shadow)),
            color: colors[byte(Off.color)].map(signed) ?? "Code \(byte(Off.color))",
            sharpness: signed(4 - byte(Off.sharpness)),
            noiseReduction: signed(byte(Off.noiseReduction) - 4))
    }

    // Firmware table BKUP_FILM_SIM_*.
    static let films = [0: "PROVIA/Standard", 1: "ASTIA/Soft", 3: "Velvia/Vivid", 5: "Sepia", 7: "Monochrome",
                        8: "Monochrome + R Filter", 9: "Monochrome + Ye Filter", 10: "Monochrome + G Filter",
                        11: "PRO Neg. Std", 12: "PRO Neg. Hi", 13: "Classic Chrome", 14: "ACROS",
                        15: "ACROS + R Filter", 16: "ACROS + Ye Filter", 17: "ACROS + G Filter", 18: "ETERNA/Cinema"]
    static let grains = [0: "Strong", 1: "Weak", 2: "Off"]
    static let chromes = [0: "Off", 1: "Weak", 2: "Strong"]
    // Firmware table BKUP_DRANGE_*.
    static let dynamicRanges = [0: "Auto", 1: "DR100", 2: "DR200", 3: "DR400"]
    // Firmware table BKUP_STILLCOLOR_*: stored code -> colour setting.
    static let colors = [0: 0, 3: 4, 4: 3, 5: 2, 6: 1, 8: -1, 7: -2, 9: -3, 10: -4]
    // Firmware table BKUP_WB_*.
    static let wbModes = [0: "Auto", 1: "Daylight", 2: "Shade", 3: "Fluorescent 1", 4: "Fluorescent 2", 5: "Fluorescent 3",
                          6: "Incandescent", 7: "Underwater", 9: "Custom 1", 10: "Custom 2", 11: "Custom 3"]
    static let kelvinWB = 8
    // Colour temperatures the camera offers, from the warmest stored code (0 = 10000 K).
    static let kelvins = [10000, 9100, 8300, 7700, 7100, 6700, 6300, 5900, 5600, 5300, 5000, 4800, 4500, 4300, 4200, 4000,
                          3800, 3700, 3600, 3400, 3300, 3200, 3100, 3000, 2950, 2850, 2800, 2700, 2650, 2550, 2500]

    static func whiteBalance(_ wb: Int, kelvin: Int) -> String {
        if wb == kelvinWB { return kelvins.indices.contains(kelvin) ? "\(kelvins[kelvin])K" : "Kelvin (code \(kelvin))" }
        return wbModes[wb] ?? "Code \(wb)"
    }
}

/// "+2", "0", "−1" (with a real minus sign).
func signed(_ v: Int) -> String {
    v > 0 ? "+\(v)" : v < 0 ? "−\(-v)" : "0"
}
