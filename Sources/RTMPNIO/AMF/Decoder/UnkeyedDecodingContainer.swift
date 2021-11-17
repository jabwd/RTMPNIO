import NIO

extension _AMFDecoder {
    final class UnkeyedContainer {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        var buffer: ByteBuffer
        var referenceTable: [AMFDecodingContainer]
        var marker: AMF0TypeMarker?
        var currentIndex: Int = 0

        lazy var count: Int? = {
            do {
                let marker = try readMarker()
                switch marker {
                case .strictArray:
                    return Int(try readInteger(as: UInt32.self))
                case .reference:
                    return -1
                default:
                    return nil
                }
            } catch {
                return nil
            }
        }()

        lazy var nestedContainers: [AMFDecodingContainer] = {
            guard let count = self.count else {
                return []
            }
            // TODO.
            return []
        }()

        init(buffer: ByteBuffer, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any], referenceTable: [AMFDecodingContainer]) {
            self.buffer = buffer
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.referenceTable = referenceTable
        }

        // MARK: -

        var isAtEnd: Bool {
            guard let count = count else {
                return true
            }
            return currentIndex >= count
        }

        func canDecodeValue() throws {
            if isAtEnd || marker != nil {
                throw DecodingError.dataCorruptedError(in: self, debugDescription: "Unexpected end of container")
            }
        }
    }
}

extension _AMFDecoder.UnkeyedContainer : AMFDecodingContainer {}

extension _AMFDecoder.UnkeyedContainer : UnkeyedDecodingContainer {
    func decodeNil() throws -> Bool {
        try canDecodeValue()
        defer { currentIndex += 1 }

        let container = nestedContainers[currentIndex] as! _AMFDecoder.SingleValueContainer
        let value = container.decodeNil()
        return value
    }

    func decode<T>(_: T.Type) throws -> T where T : Decodable {
        try canDecodeValue()
        defer { currentIndex += 1 }

        if marker == .null {
            let singleValueContainer = _AMFDecoder.SingleValueContainer(
                buffer: buffer,
                codingPath: codingPath,
                userInfo: userInfo,
                referenceTable: referenceTable
            )
            let decoder = _AMFDecoder(buffer: singleValueContainer.buffer, referenceTable: referenceTable)
            let value = try T(from: decoder)
            return value
        }

        let container = nestedContainers[currentIndex]
        let decoder = _AMFDecoder(buffer: container.buffer, referenceTable: referenceTable)
        let value = try T(from: decoder)
        return value
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try canDecodeValue()
        defer { currentIndex += 1 }

        let container = nestedContainers[currentIndex] as! _AMFDecoder.UnkeyedContainer
        return container
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try canDecodeValue()
        defer { currentIndex += 1 }

        let container = nestedContainers[currentIndex] as! _AMFDecoder.KeyedContainer<NestedKey>
        return KeyedDecodingContainer(container)
    }

    func superDecoder() throws -> Decoder {
        _AMFDecoder(buffer: buffer, referenceTable: referenceTable)
    }
}

extension _AMFDecoder.UnkeyedContainer {
    func decodeContainer() throws -> AMFDecodingContainer {
        try canDecodeValue()
        defer { currentIndex += 1 }

        // I am pretty sure I need none of this code because I'm using a ByteBuffer lol
//        let startIndex = index
//        let length: Int
//        let marker = try readMarker()
//
//        switch marker {
//        case .object, .ecmaArray:
//            break
//        case .boolean:
//            length = 1
//        case .number:
//            length = 8
//        case .string:
//            length = Int(try readInteger(as: UInt16.self))
//        case .reference:
//            let reference = Int(try readInteger(as: UInt16.self))
//            guard reference < referenceTable.count else {
//                throw DecodingError.dataCorruptedError(in: self, debugDescription: "Reference index out of bounds \(reference), table: \(referenceTable.count)")
//            }
//            return referenceTable[reference]
//        default:
//            throw DecodingError.dataCorruptedError(in: self, debugDescription: "Invalid marker for unkeyed container")
//        }

        let container = _AMFDecoder.SingleValueContainer(
            buffer: buffer,
            codingPath: codingPath,
            userInfo: userInfo,
            referenceTable: referenceTable
        )
        return container
    }
}
