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
            
            if let m = Message(data: messageBytes) {
                switch m {
                case .manufacturer(let manufacturer, let payload):
                    print("Manufacturer: \(manufacturer.displayName)")

                    if manufacturer == Manufacturer.korg {
                        identifyKorg(manufacturer: manufacturer, payload: payload)
                    }
                    else {
                        print("Can't handle SysEx for \(manufacturer.displayName) yet")
                    }
                case .universal(let kind, let header, let payload):
                    print("Universal: \(kind), header = \(header), payload: \(payload.count) bytes")
                }
            }
        }
    }
}

SyxIdent.main()
