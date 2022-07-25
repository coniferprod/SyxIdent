import ArgumentParser
import Foundation
import SyxPack

struct SyxIdent: ParsableCommand {
    @Option var inputFile: String

    mutating func run() throws {
        print("inputFile = \(inputFile)")
        
        let messageData = try Data(contentsOf: URL(fileURLWithPath: inputFile))
        
        // Check for multiple SysEx messages in the same file
        let messages = messageData.split(separator: 0xF7)
        if messages.count > 1 {
            print("Found \(messages.count) System Exclusive messages in the same file")
            print("")
        }

        for (index, message) in messages.enumerated() {
            print("Message #\(index + 1):")

            var messageBytes = ByteArray(message)
            messageBytes.append(0xF7)  // add back the terminator lost by split(:)

            var regions = [Region]()
            
            if let m = Message(data: messageBytes) {
                var adjustment = 0  // how many bytes to adjust the offsets
                
                regions.insert(Region(key: "Status", value: "System Exclusive start", start: 0, data: ByteArray(arrayLiteral: 0xf0)), at: 0)
                adjustment += 1

                switch m {
                case .manufacturer(let manufacturer, let payload):
                    //print("Manufacturer: \(manufacturer.displayName)")

                    if manufacturer == Manufacturer.korg {
                        regions.append(Region(key: "Manufacturer", value: manufacturer.displayName, start: 1, data: manufacturer.getBytes()))
                        adjustment += manufacturer.length
                        
                        let payloadRegions = Korg.identify(payload: payload)
                        let adjustedPayloadRegions = payloadRegions.map {
                            Region(key: $0.key, value: $0.value, start: $0.start + adjustment, data: $0.data)
                        }
                        regions.append(contentsOf: adjustedPayloadRegions)
                    }
                    else {
                        print("Can't handle SysEx for \(manufacturer.displayName) yet")
                        continue
                    }
                                        
                case .universal(let kind, let header, let payload):
                    var universalValue = ""
                    if kind == .nonRealTime {
                        universalValue = "Non-Real-time"
                    }
                    else if kind == .realTime {
                        universalValue = "Real-time"
                    }
                    // FIXME: figure out correct data for Universal SysEx
                    regions.append(Region(key: "Universal", value: universalValue, start: 1, data: ByteArray()))
                    regions.append(Region(key: "Payload", value: "\(payload.count) bytes", start: 2, data: ByteArray()))
                }
                
                regions.append(Region(key: "Status", value: "System Exclusive end", start: messageBytes.count - 1, data: ByteArray(arrayLiteral: 0xf7)))
                
                for region in regions {
                    print("\(String(format: "%06X", region.start)): \(region.key): \(region.value) [\(region.data.dump(length: 8))]")
                }
            }
        }
    }
}

extension Manufacturer {
    func getBytes() -> ByteArray {
        var result = ByteArray()
        switch self.identifier {
        case .standard(let b):
            result.append(b)
        case .extended(let b):
            result.append(b.0)
            result.append(b.1)
            result.append(b.2)
        case .development:
            result.append(0x7d)
        }
        return result
    }
}

extension ByteArray {
    func dump(length: Int) -> String {
        var byteCount = length
        if byteCount > self.count {
            byteCount = self.count
        }
        var result = ""
        var i = 0
        while i < byteCount {
            result += String(format: "%02X", self[i])
            i += 1
            if i < byteCount {
                result += " "
            }
        }
        if length < self.count {
            result += "..."
        }
        return result
    }
}

SyxIdent.main()
