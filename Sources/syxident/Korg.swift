import Foundation
import SyxPack

let korgSynths: [UInt: String] = [
    0x28: "Wavestation",
    0x36: "05R/W",
    0x012c: "minilogue",
    0x0144: "monologue",
    0x014b: "prologue",
    0x0151: "minilogue xd",
    0x0157: "nu:tekt NTS-1",
]

// The Wavestation System Exclusive commands.
// The CaseIterable protocol allows us to get all the cases.
enum Wavestation {
    enum Command: String, CaseIterable {
        case singlePatchDump = "Single Patch Dump"
        case singlePerformanceDump = "Single Performance Dump"
        case allPatchDump = "All Patch Dump"
        case allPerformanceDump = "All Performance Dump"
        case systemSetupDump = "System Setup Dump"
        case systemSetupExpandedDump = "System Setup Expanded Dump"
        case waveSequenceDump = "Wave Sequence Dump"
        case multiModeSetupDump = "Multi Mode Setup Dump"
        case multiModeSetupExpandedDump = "Multi Mode Setup Expanded Dump"
        case performanceMapDump = "Performance Map Dump"
        case performanceMapExpandedDump = "Performance Map Expanded Dump"
        case microTuneScaleDump = "Micro Tune Scale Dump"
        case allDataDump = "All Data Dump"

        init?(id: Byte) {
            switch id {
            case 0x40: self = .singlePatchDump
            case 0x49: self = .singlePerformanceDump
            case 0x4c: self = .allPatchDump
            case 0x4d: self = .allPerformanceDump
            case 0x51: self = .systemSetupDump
            case 0x5c: self = .systemSetupExpandedDump
            case 0x54: self = .waveSequenceDump
            case 0x55: self = .multiModeSetupDump
            case 0x5e: self = .multiModeSetupExpandedDump
            case 0x5d: self = .performanceMapDump
            case 0x5f: self = .performanceMapExpandedDump
            case 0x5a: self = .microTuneScaleDump
            case 0x50: self = .allDataDump
            default: return nil
            }
        }

        func asByte() -> Byte {
            switch self {
            case .singlePatchDump: return 0x40
            case .singlePerformanceDump: return 0x49
            case .allPatchDump: return 0x4c
            case .allPerformanceDump: return 0x4d
            case .systemSetupDump: return 0x51
            case .systemSetupExpandedDump: return 0x5c
            case .waveSequenceDump: return 0x54
            case .multiModeSetupDump: return 0x55
            case .multiModeSetupExpandedDump: return 0x5e
            case .performanceMapDump: return 0x5d
            case .performanceMapExpandedDump: return 0x5f
            case .microTuneScaleDump: return 0x5a
            case .allDataDump: return 0x50
            }
        }
    }
}

func identifyKorg(manufacturer: Manufacturer, payload: Payload) {
    //print("Payload length = \(payload.count) bytes")
    
    let channel = payload[0].lowNybble + 1
    print("Channel: \(channel)")
    
    let synthId = payload[1]
    if synthId == 0x00 {
        let familyId = UInt16(payload[2]) | (UInt16(payload[3]) << 8)
        if let synthName = korgSynths[UInt(familyId)] {
            print("Model: \(synthName)")
        }
        else {
            print("Model: (unknown)")
        }
    }
    else {
        if let synthName = korgSynths[UInt(synthId)] {
            print("Model: \(synthName)")
        }
    }
    
    var dataStartOffset = 0
    
    switch synthId {
    case 0x28:
        // KORG Wavestation SysEx messages have a varying header and
        // then data in two-nybble format payload (with low nybble first).
        // The data is followed by a checksum,
        // but the header is not included in the checksum.

        // Raw data is everything but the first three bytes (3n 28 msg)
        // and the last byte (the original checksum)
        let rawData = ByteArray(payload.dropFirst(3).dropLast())
        //print("raw data length = \(rawData.count) bytes")
        
        dataStartOffset = 1
        
        if let command = Wavestation.Command(id: payload[2]) {
            print("Command: \(command.rawValue)")
            
            let bank = rawData.first!
            switch command {
            case .singlePatchDump:
                print("Bank: \(bank)")
                print("Patch: \(rawData[1])")
                dataStartOffset += 1
            case .singlePerformanceDump:
                print("Bank: \(bank)")
                print("Performance: \(rawData[1])")
                dataStartOffset += 1
            case .allPatchDump:
                print("Bank: \(bank)")
            case .allPerformanceDump:
                print("Bank: \(bank)")
            case .waveSequenceDump:
                print("Bank: \(bank)")
            default:  // no additional parameters to show
                break
            }
        }

        let originalChecksum = payload.last!
        print("Original checksum: \(String(format: "%02X", originalChecksum))h")
        let calculatedChecksum = calculateWavestationChecksum(data: rawData)
        if originalChecksum == calculatedChecksum {
            print("Checksums match!")
        }
        else {
            print("Calculated checksum: \(String(format: "%02X", calculatedChecksum))h")
            print("Checksums don't match.")
        }

        if let data = ByteArray(rawData.dropFirst(dataStartOffset)).denybblified(highFirst: false) {
            print("final data: \(data.count) bytes")
        }
        else {
            print("error: data byte count should be even")
            return
        }
        
    case 0x36:
        //let rawData = ByteArray(payload.dropFirst(3).dropLast())
        
        let functionCode = payload[2]
        switch functionCode {
        case 0x40:
            print("Program Parameter Dump")
        case 0x4C:
            print("All Program Parameter Dump")
        case 0x49:
            print("Combination Parameter Dump")
        case 0x4D:
            print("All Combination Parameter Dump")
        case 0x55:
            print("Multi Setup Data Dump")
        case 0x51:
            print("Global Data Dump")
        case 0x52:
            print("Drums Data Dump")
        case 0x50:
            print("All Data (Global, Drums, Combi, Prog, Multi) Dump")
        default:
            print("Something not known at this time")
        }
        
    case 0x00:  // possibly one of the 'logue family (e.g. 00 01 2C)
        let familyId = UInt16(payload[2]) | (UInt16(payload[3]) << 8)
        switch familyId {
        case 0x012c:
            print("minilogue")
        case 0x0144:
            print("monologue")
        case 0x014b:
            print("prologue")
        case 0x0151:
            print("minilogue xd")
        case 0x0157:
            print("nu:tekt NTS-1")
        default:
            print("Some unknown 'logue")
        }
    
    default:
        print("Can't identify the synth right now.")
    }
}

func calculateWavestationChecksum(data: ByteArray) -> Byte {
    var result: Int = 0
    
    data.forEach { b in
        result += Int(b)
    }
    
    result = result & 0x7f
    return Byte(result)
}

public struct LogueDeviceInformation {
    let family: UInt16
    let member: UInt16
    let majorVersion: UInt16
    let minorVersion: UInt16
    
    public init(data: ByteArray) {
        self.family = UInt16(data[6]) | (UInt16(data[7]) << 8)
        self.member = UInt16(data[8]) | (UInt16(data[9]) << 8)
        self.majorVersion = UInt16(data[10]) | (UInt16(data[11]) << 8)
        self.minorVersion = UInt16(data[12]) | (UInt16(data[13]) << 8)
    }
}

extension LogueDeviceInformation: CustomStringConvertible {
    public var description: String {
        let logueFamily: [UInt16: String] = [
            0x012c: "minilogue",
            0x0144: "monologue",
            0x014b: "prologue",
            0x0151: "minilogue xd",
            0x0157: "nu:tekt NTS-1",
        ]

        var familyName = "(unknown)"
        if let name = logueFamily[self.family] {
            familyName = name
        }
        return
            "Family : \(String(format: "%04X", self.family)) / \(familyName)\n" +
            "Member : \(String(format: "%04X", self.member))\n" +
            "Version: \(self.majorVersion).\(String(format: "%02d", minorVersion))"
    }
}

public struct Program {
    var name: String
    var octave: Int
    // etc.
    
    public init(data: ByteArray) {
        let nameBytes = ByteArray(data[4...15])
        self.name = String(bytes: nameBytes, encoding: .utf8) ?? "(unknown)"
        
        self.octave = Int(data[16]) - 2  // -2~+2
        // etc.
    }
}

extension Program: CustomStringConvertible {
    public var description: String {
        return "\(self.name)"
    }
}
