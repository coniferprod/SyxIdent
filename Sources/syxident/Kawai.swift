import Foundation
import SyxPack

struct Kawai {
    enum Model: Byte, CaseIterable {
        case k5 = 0x02
        case k1ii = 0x03
        case k4 = 0x04
        
        public var description: String {
            switch self {
            case .k5:
                return "K5/K5m"
            case .k1ii:
                return "K1 II"
            case .k4:
                return "K4/K4r"
            }
        }
        
        static func isValid(modelId: Byte) -> Bool {
            return self.allCases.map { $0.rawValue }.contains(modelId)
        }
    }
    
    struct K4 {
        enum Cardinality: Byte {
            case one = 0x20
            case block = 0x21
            case all = 0x22
        }
        
        enum Locality {
            case int
            case ext
        }
        
        enum Function: Byte, CaseIterable, CustomStringConvertible {
            case onePatchDataDump = 0x20
            case blockPatchDataDump = 0x21
            case allPatchDataDump = 0x22
            case programChange = 0x30
            case writeComplete = 0x40
            case writeError = 0x41
            case writeErrorProtect = 0x42
            case writeErrorNoCard = 0x43
            case onePatchDataRequest = 0x00
            case blockPatchDataRequest = 0x01
            case allPatchDataRequest = 0x02
            
            public var description: String {
                switch self {
                case .onePatchDataDump:
                    return "One Patch Data Dump"
                case .blockPatchDataDump:
                    return "Block Patch Data Dump"
                case .allPatchDataDump:
                    return "All Data Dump"
                case .programChange:
                    return "Program Change (INT/EXT)"
                case .writeComplete:
                    return "Write Complete"
                case .writeError:
                    return "Write Error"
                case .writeErrorProtect:
                    return "Write Error (Protect)"
                case .writeErrorNoCard:
                    return "Write Error (No Card)"
                case .onePatchDataRequest:
                    return "One Patch Data Request"
                case .blockPatchDataRequest:
                    return "Block Patch Data Request"
                case .allPatchDataRequest:
                    return "All Patch Data Request"
                }
            }
        }
        
        struct Message {
            let channel: Byte
            let function: Byte
            let group: Byte
            let machineId: Byte
            let substatus1: Byte
            let substatus2: Byte
            
            func size() -> Int {
                return 6
            }
        }
    }
    
    static func identify(payload: Payload) -> [Region] {
        var regions = [Region]()
        var offset = 0
        
        let message = K4.Message(
            channel: payload[0].lowNybble,
            function: payload[1],
            group: payload[2],
            machineId: payload[3],
            substatus1: payload[4],
            substatus2: payload[5])
        
        regions.append(Region(key: "Channel no.", value: "\(message.channel + 1)", start: 0, data: ByteArray(arrayLiteral: payload[0])))
        offset += 1
        
        var modelValue = "Unknown"
        if Kawai.Model.isValid(modelId: message.machineId) {
            if let model = Kawai.Model.init(rawValue: message.machineId) {
                modelValue = model.description
            }
        }
        else {
            print("Unknown Kawai model value")
            return regions
        }
        
        if let model = Kawai.Model.init(rawValue: message.machineId) {
            switch model {
            case .k4:
                var substatus1Value = ""
                var substatus2Value = "N/A"

                if let function = K4.Function(rawValue: message.function) {
                    var functionData = ByteArray()
                    functionData.append(message.function)

                    var functionValue = "'\(function.description)'"
                    
                    var cardinality = K4.Cardinality.one
                    var locality = K4.Locality.int
                    
                    switch function {
                    case .onePatchDataDump, .onePatchDataRequest:
                        if message.substatus1 == 0x00 || message.substatus1 == 0x01 {
                            substatus1Value = "Internal"
                        }
                        if message.substatus1 == 0x00 || message.substatus1 == 0x02 { // single or multi
                            if message.substatus2 <= 63 {
                                substatus2Value += "\(message.substatus2) SINGLE \(message.substatus2 + 1)"
                            }
                            else {
                                substatus2Value += "\(message.substatus2) MULTI \(message.substatus2 + 1)"
                            }
                        }
                        if message.substatus1 == 0x01 || message.substatus1 == 0x03 { // drum or effect
                            if message.substatus2 <= 31 {
                                substatus2Value += "\(message.substatus2) EFFECT \(message.substatus2 + 1)"
                            }
                            else {
                                substatus2Value += "DRUM"
                            }
                        }
                                                
                    case .blockPatchDataDump, .blockPatchDataRequest:
                        cardinality = .block
                        let substatus = (message.substatus1, message.substatus2)
                        switch substatus {
                        case let (loc, kind):
                            if loc == 0x00 || loc == 0x02 {  // singles or multis
                                if loc == 0x02 {
                                    locality = .ext
                                }
                                if kind == 0x00 {
                                    substatus2Value += "All singles"
                                }
                                else if kind == 0x40 {
                                    substatus2Value += "All multis"
                                }
                            }
                            if loc == 0x01 || loc == 0x03 {  // effects
                                if loc == 0x03 {
                                    locality = .ext
                                }
                                if kind == 0x00 {
                                    substatus2Value += "All effects"
                                }
                            }
                        }
                    
                    case .allPatchDataDump, .allPatchDataRequest:
                        cardinality = .all
                        let substatus = (message.substatus1, message.substatus2)
                        switch substatus {
                        case let (loc, _):
                            substatus1Value = "INT"
                            if loc == 0x00 || loc == 0x02 {
                                if loc == 0x02 {
                                    locality = .ext
                                    substatus1Value = "EXT"
                                }
                            }
                        }
                        
                    case .programChange:
                        functionValue += ": "
                        if message.substatus1 == 0x00 {
                            functionValue += "INT"
                        }
                        else if message.substatus1 == 0x02 {
                            functionValue += "EXT"
                        }
                                                
                    default:
                        break
                    }

                    regions.append(Region(key: "Function no.", value: functionValue, start: 1, data: functionData))
                }
                
                regions.append(Region(key: "Group no.", value: "Synthesizer group", start: 2, data: ByteArray(arrayLiteral: message.group)))
                regions.append(Region(key: "Machine ID no.", value: modelValue, start: 3, data: ByteArray(arrayLiteral: message.machineId)))
                regions.append(Region(key: "Sub status 1", value: substatus1Value, start: 4, data: ByteArray(arrayLiteral: message.substatus1)))
                regions.append(Region(key: "Sub status 2", value: substatus2Value, start: 5, data: ByteArray(arrayLiteral: message.substatus2)))
                
                let data = ByteArray(payload.dropFirst(message.size()))
                regions.append(Region(key: "Data", value: "\(data.count) bytes", start: message.size(), data: data))

            case .k5:
                break
                
            case .k1ii:
                break
            }
        }

        return regions
    }
}
