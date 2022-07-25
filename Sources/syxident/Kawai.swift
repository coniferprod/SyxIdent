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
    }
    
    static func identify(payload: Payload) -> [Region] {
        var regions = [Region]()
        var offset = 0
        
        let channel = payload[0].lowNybble + 1
        regions.append(Region(key: "Channel", value: "\(channel)", start: 0, data: ByteArray(arrayLiteral: payload[0])))
        offset += 1
        
        let synthId = payload[3]
        var modelValue = "Unknown"
        if Kawai.Model.isValid(modelId: synthId) {
            if let model = Kawai.Model.init(rawValue: synthId) {
                modelValue = model.description
            }
        }
        else {
            print("Unknown Kawai model value")
            return regions
        }
        
        regions.append(Region(key: "Model", value: modelValue, start: 1, data: ByteArray(arrayLiteral: synthId)))
        offset += 1
        
        if let model = Kawai.Model.init(rawValue: synthId) {
            switch model {
            case .k4:
                if let function = K4.Function(rawValue: payload[1]) {
                    var functionData = ByteArray()
                    functionData.append(payload[1])

                    var functionValue = "'\(function.description)'"
                    
                    var cardinality = K4.Cardinality.one
                    var locality = K4.Locality.int

                    switch function {
                    case .onePatchDataDump, .onePatchDataRequest:
                        let substatus = (payload[5], payload[6])
                        switch substatus {
                        case let (loc, num):
                            if loc == 0x00 || loc == 0x02 {  // single or multi
                                if loc == 0x02 {
                                    locality = .ext
                                }
                                if num <= 63 {
                                    functionValue += "SINGLE \(num + 1)"
                                }
                                else {
                                    functionValue += "MULTI \(num + 1)"
                                }
                            }
                            if loc == 0x01 || loc == 0x03 {  // drum or effect
                                if loc == 0x03 {
                                    locality = .ext
                                }
                                if num <= 31 {
                                    functionValue += "EFFECT \(num + 1)"
                                }
                                else {
                                    functionValue += "DRUM"
                                }
                            }
                        }
                        offset += 2
                                                
                    case .blockPatchDataDump, .blockPatchDataRequest:
                        cardinality = .block
                        let substatus = (payload[5], payload[6])
                        switch substatus {
                        case let (loc, kind):
                            if loc == 0x00 || loc == 0x02 {  // singles or multis
                                if loc == 0x02 {
                                    locality = .ext
                                }
                                if kind == 0x00 {
                                    functionValue += "All singles"
                                }
                                else if kind == 0x40 {
                                    functionValue += "All multis"
                                }
                            }
                            if loc == 0x01 || loc == 0x03 {  // effects
                                if loc == 0x03 {
                                    locality = .ext
                                }
                                if kind == 0x00 {
                                    functionValue += "All effects"
                                }
                            }
                        }
                        offset += 2
                    
                    case .allPatchDataDump, .allPatchDataRequest:
                        cardinality = .all
                        let substatus = (payload[5], payload[6])
                        switch substatus {
                        case let (loc, _):
                            if loc == 0x00 || loc == 0x02 {
                                if loc == 0x02 {
                                    locality = .ext
                                }
                            }
                        }
                        offset += 2
                        
                    case .programChange:
                        functionValue += ": "
                        let substatus1 = payload[5]
                        if substatus1 == 0x00 {
                            functionValue += "INT"
                        }
                        else if substatus1 == 0x02 {
                            functionValue += "EXT"
                        }
                                                
                    default:
                        break
                    }

                    regions.append(Region(key: "Function", value: functionValue, start: offset, data: functionData))
                    offset += 1
                }

            case .k5:
                break
                
            case .k1ii:
                break
            }
        }

        return regions
    }
}
