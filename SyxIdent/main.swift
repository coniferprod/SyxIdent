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
enum WavestationCommand: String, CaseIterable {
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

guard CommandLine.arguments.count >= 2 else {
    print("Need a filename")
    exit(-1)
}

let filename = CommandLine.arguments[1]
print("Reading System Exclusive message from \(filename)")

let messageData = try Data(contentsOf: URL(fileURLWithPath: filename))

// Check for multiple SysEx messages in the same file
let messages = messageData.split(separator: 0xF7)
if messages.count > 1 {
    print("Found \(messages.count) System Exclusive messages in the same file")
    print("")
}

// TODO: Check that just one message in a file is handled transparently

//let messageData: ByteArray = [0xF0, 0x42, 0x30, 0x01, 0x51, 0x17, 0xF7]
//print("Message length: \(messageData.bytes.count) bytes")
//identifyMessage(data: messageData.bytes)

for (index, message) in messages.enumerated() {
    print("Message #\(index + 1):")

    var messageBytes = ByteArray(message)
    messageBytes.append(0xF7)  // add back the terminator lost by split(:)
    //identifyMessage(data: messageBytes)
    
    if let m = Message(data: messageBytes) {
        switch m {
        case .manufacturer(let manufacturer, let payload):
            if manufacturer == Manufacturer.korg {
                print("Manufacturer: \(manufacturer.displayName)")
                
                let synthId = messageBytes[3]
                if synthId == 0x00 {
                    let familyId = UInt16(messageBytes[4]) | (UInt16(messageBytes[5]) << 8)
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
                
                switch synthId {
                case 0x28:
                    var startOffset = 6

                    if let command = WavestationCommand(id: messageBytes[4]) {
                        print("Command: \(command)")
                        
                        switch command {
                        case .singlePatchDump:
                            startOffset = 7
                            print("Bank: \(messageBytes[5])")
                            print("Patch: \(messageBytes[6])")
                        case .singlePerformanceDump:
                            print("Bank: \(messageBytes[5])")
                            print("Performance: \(messageBytes[6])")
                        case .allPatchDump:
                            print("Bank: \(messageBytes[5])")
                        case .allPerformanceDump:
                            print("Bank: \(messageBytes[5])")
                        case .waveSequenceDump:
                            print("Bank: \(messageBytes[5])")
                        default:  // no additional parameters to show
                            break
                        }
                    }

                    // KORG Wavestation SysEx messages have a varying header and
                    // two-nybble format payload, with low nybble first.
                    // The payload is followed by a checksum, right before the terminator.
                    let endOffset = messageBytes.count - 2 // leave out terminator and checksum
                    let payload = ByteArray(messageBytes[startOffset ..< endOffset])
                    
                    let originalChecksum = messageBytes[endOffset]
                    print("Original checksum: \(String(format: "%02X", originalChecksum))h")
                    let calculatedChecksum = calculateWavestationChecksum(data: payload)
                    if originalChecksum == calculatedChecksum {
                        print("Matches computed checksum.")
                    }
                    else {
                        print("Calculated checksum: \(String(format: "%02X", calculatedChecksum))h")
                        print("No match.")
                    }

                    if let payload = payload.denybblified(highFirst: false) {
                        print("payload: \(payload.count) bytes")
                        //print(payload.hexDump())
                    }
                    else {
                        print("error: payload byte count should be even")
                        continue
                    }
                    
                case 0x36:
                    print("05R/W")
                    
                    var startOffset = 5
                    let commandId = messageBytes[4]
                    switch commandId {
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
                    let familyId = UInt16(messageBytes[4]) | (UInt16(messageBytes[5]) << 8)
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
            
        case .universal(let kind, let header, let payload):
            print("Universal: \(kind), header = \(header), payload: \(payload.count) bytes")
        }
    }
    
    print("")
}

func calculateWavestationChecksum(data: ByteArray) -> Byte {
    var result: Int = 0
    
    data.forEach { b in
        result += Int(b)
    }
    
    result = result & 0x7f
    return Byte(result)
}

/*
let packedPayload = ByteArray(messageData.bytes[startOffset ..< endOffset])
let unpackedPayload = packedPayload.unpacked()
print("packed: \(packedPayload.count)")
print("unpacked: \(unpackedPayload.count)")
*/

/*
if let message = Message(data: messageData.bytes) {
    print(message)
    
    var config = HexDumpConfig.defaultConfig
    config.includeOptions = []
    let bytesToPrint = min(16, message.payload.count)
    print(ByteArray(message.payload[..<bytesToPrint]).hexDump(config: config))
    if bytesToPrint < message.payload.count {
        print(" (+ \(message.payload.count - bytesToPrint) more bytes)")
    }
}
else {
    print("No valid System Exclusive message found")
}
*/

/*
let messageData: ByteArray = [
    0xF0, 0x7E, 0x00,
    0x06, 0x02, 0x42,
    0x51, 0x01,
    0x00, 0x00,
    0x02, 0x00,
    0x01, 0x00,
    0xF7]
print("Message length: \(messageData.count) bytes")
print("KORG 'logue Device Information:")
let deviceInformation = LogueDeviceInformation(data: messageData)
print(deviceInformation)
*/

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

/*
let program = Program(data: unpackedPayload)
print("Program: '\(program)'")

let repackedPayload = unpackedPayload.packed()
print("repacked: \(repackedPayload.count)")
assert(repackedPayload == packedPayload)
*/
