import SyxPack

struct Region: CustomStringConvertible {
    let key: String
    let value: String
    let start: Int
    let data: ByteArray
    
    var description: String {
        let hexStart = String(format: "%06X", start)
        let hexEnd = String(format: "%06X", start + data.count - 1)
        return "\(key): \(value) \(hexStart)...\(hexEnd) (\(data.count))"
    }
}

extension Manufacturer {
    var length: Int {
        if case .extended(_) = self.identifier {
            return 3
        }
        else {
            return 1
        }
    }
}
