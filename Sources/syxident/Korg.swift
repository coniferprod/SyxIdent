import Foundation
import SyxPack

struct Korg {
    enum Model: UInt, CaseIterable {
        case wavestation = 0x28
        case o5rw = 0x36
        case minilogue = 0x012c
        case monologue = 0x0144
        case prologue = 0x014b
        case miniloguexd = 0x0151
        case nts1 = 0x0157
        
        public var description: String {
            switch self {
            case .wavestation:
                return "Wavestation"
            case .o5rw:
                return "05R/W"
            case .minilogue:
                return "minilogue"
            case .monologue:
                return "monologue"
            case .prologue:
                return "prologue"
            case .miniloguexd:
                return "minilogue xd"
            case .nts1:
                return "nu:tekt NTS-1"
            }
        }
        
        static func isValid(modelId: UInt) -> Bool {
            return self.allCases.map { $0.rawValue }.contains(modelId)
        }
    }
    
    struct Wavestation {
        // The Wavestation System Exclusive commands.
        // The CaseIterable protocol allows us to get all the cases.
        enum Command: Byte, CaseIterable, CustomStringConvertible {
            case singlePatchDump = 0x40
            case singlePerformanceDump = 0x49
            case allPatchDump = 0x4c
            case allPerformanceDump = 0x4d
            case systemSetupDump = 0x51
            case systemSetupExpandedDump = 0x5c
            case waveSequenceDump = 0x54
            case multiModeSetupDump = 0x55
            case multiModeSetupExpandedDump = 0x5e
            case performanceMapDump = 0x5d
            case performanceMapExpandedDump = 0x5f
            case microTuneScaleDump = 0x5a
            case allDataDump = 0x50
            
            public var description: String {
                switch self {
                case .singlePatchDump:
                    return "Single Patch Dump"
                case .singlePerformanceDump:
                    return "Single Performance Dump"
                case .allPatchDump:
                    return "All Patch Dump"
                case .allPerformanceDump:
                    return "All Performance Dump"
                case .systemSetupDump:
                    return "System Setup Dump"
                case .systemSetupExpandedDump:
                    return "System Setup Expanded Dump"
                case .waveSequenceDump:
                    return "Wave Sequence Dump"
                case .multiModeSetupDump:
                    return "Multi Mode Setup Dump"
                case .multiModeSetupExpandedDump:
                    return "Multi Mode Setup Expanded Dump"
                case .performanceMapDump:
                    return "Performance Map Dump"
                case .performanceMapExpandedDump:
                    return "Performance Map Expanded Dump"
                case .microTuneScaleDump:
                    return "Micro Tune Scale Dump"
                case .allDataDump:
                    return "All Data Dump"
                }
            }
        }
        
        static func checksum(data: ByteArray) -> Byte {
            var result: Int = 0
            
            data.forEach { b in
                result += Int(b)
            }
            
            result = result & 0x7f
            return Byte(result)
        }
    }
        
    static func identify(payload: Payload) -> [Region] {
        //print("Payload length = \(payload.count) bytes")
        
        var regions = [Region]()
        var offset = 0
        let channel = payload[0].lowNybble + 1
        //print("Channel: \(channel)")
        regions.append(Region(key: "Channel", value: "\(channel)", start: 0, data: ByteArray(arrayLiteral: payload[0])))
        offset += 1
        
        let synthId = payload[1]
        if synthId == 0x00 {
            let familyId = UInt16(payload[2]) | (UInt16(payload[3]) << 8)
            var modelValue = "Unknown"
            if Korg.Model.isValid(modelId: UInt(familyId)) {
                if let model = Korg.Model.init(rawValue: UInt(familyId)) {
                    modelValue = model.description
                }
            }
            regions.append(Region(key: "Model", value: modelValue, start: 1, data: ByteArray(arrayLiteral: payload[2], payload[3])))
            offset += 2
        }
        else {
            var modelValue = "Unknown"
            if Korg.Model.isValid(modelId: UInt(synthId)) {
                if let model = Korg.Model.init(rawValue: UInt(synthId)) {
                    modelValue = model.description
                }
            }
            regions.append(Region(key: "Model", value: modelValue, start: 1, data: ByteArray(arrayLiteral: synthId)))
            offset += 1
        }
        
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
            
            let startOffset = offset
            
            if let command = Wavestation.Command(rawValue: payload[2]) {
                var commandData = ByteArray()
                commandData.append(payload[2])

                var commandValue = ""

                let bank = rawData.first!
                switch command {
                case .singlePatchDump:
                    let patch = rawData[1]
                    commandValue = "Bank: \(bank)  Patch: \(patch)"
                    commandData.append(bank)
                    commandData.append(patch)
                    offset += 1
                case .singlePerformanceDump:
                    let performance = rawData[1]
                    commandValue = "Bank: \(bank)  Performance: \(performance)"
                    commandData.append(bank)
                    commandData.append(performance)
                    offset += 1
                case .allPatchDump:
                    commandValue = "Bank: \(bank)"
                    commandData.append(bank)
                case .allPerformanceDump:
                    commandValue = "Bank: \(bank)"
                    commandData.append(bank)
                case .waveSequenceDump:
                    commandValue = "Bank: \(bank)"
                    commandData.append(bank)
                default:  // no additional parameters to show
                    break
                }
                offset += 1
                
                regions.append(Region(key: "Command", value: commandValue, start: startOffset, data: commandData))
                offset += 1
            }

            let originalChecksum = payload.last!
            print("Original checksum: \(String(format: "%02X", originalChecksum))h")
            let calculatedChecksum = Wavestation.checksum(data: rawData)
            if originalChecksum == calculatedChecksum {
                print("Checksums match!")
            }
            else {
                print("Calculated checksum: \(String(format: "%02X", calculatedChecksum))h")
                print("Checksums don't match.")
            }
            regions.append(Region(key: "Checksum", value: "\(String(format: "%02X", originalChecksum))H", start: offset, data: ByteArray(arrayLiteral: originalChecksum)))
            offset += 1

            if let data = ByteArray(rawData.dropFirst(offset)).denybblified(highFirst: false) {
                print("final data: \(data.count) bytes")
                regions.append(Region(key: "Data", value: "\(data.count) bytes", start: offset, data: data))
            }
            else {
                print("error: data byte count should be even")
                return [Region]()
            }
            
        case 0x36:
            //let rawData = ByteArray(payload.dropFirst(3).dropLast())
            
            var commandValue = ""
            let functionCode = payload[2]
            switch functionCode {
            case 0x40:
                commandValue = "Program Parameter Dump"
            case 0x4C:
                commandValue = "All Program Parameter Dump"
            case 0x49:
                commandValue = "Combination Parameter Dump"
            case 0x4D:
                commandValue = "All Combination Parameter Dump"
            case 0x55:
                commandValue = "Multi Setup Data Dump"
            case 0x51:
                commandValue = "Global Data Dump"
            case 0x52:
                commandValue = "Drums Data Dump"
            case 0x50:
                commandValue = "All Data (Global, Drums, Combi, Prog, Multi) Dump"
            default:
                commandValue = "Something not known at this time"
            }
            
            regions.append(Region(key: "Function", value: commandValue, start: offset, data: ByteArray(arrayLiteral: functionCode)))
            offset += 1
            
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
        
        return regions
    }
        
    static func checksum(data: ByteArray) -> Byte {
        var result: Int = 0
        
        data.forEach { b in
            result += Int(b)
        }
        
        result = result & 0x7f
        return Byte(result)
    }
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
