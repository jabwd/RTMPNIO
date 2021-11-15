import NIO

extension _AMFDecoder {
    final class SingleValueContainer {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey : Any]
        var buffer: ByteBuffer
        var index: Int

        init(buffer: ByteBuffer, codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.buffer = buffer
            self.index = self.buffer.readerIndex
        }
    }
}

extension _AMFDecoder.SingleValueContainer : AMFDecodingContainer {}

extension _AMFDecoder.SingleValueContainer : SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        return false // TODO: Figure out how this is called lol
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        let marker = try readMarker()

        switch marker {
        case .boolean:
            let byte = try readByte()
            return byte != 0
        default:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid marker: \(marker)")
            throw DecodingError.typeMismatch(UInt8.self, context)
        }
    }

    func decode(_ type: String.Type) throws -> String {
        let marker = try readMarker()

        switch marker {
        case .string:
            let length: UInt16 = try readInteger(as: UInt16.self)
            return try readString(length: Int(length))

        case .longString:
            let length: UInt32 = try readInteger(as: UInt32.self)
            return try readString(length: Int(length))

        default:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Expected string got \(marker)")
            throw DecodingError.typeMismatch(String.self, context)
        }
        return ""
    }

    func decode(_ type: Double.Type) throws -> Double {
        let marker = try readMarker()

        switch marker {
        case .number:
            let value = try readInteger(as: UInt64.self)
            return Double(bitPattern: value)
        default:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Expected number got \(marker)")
            throw DecodingError.typeMismatch(String.self, context)
        }
    }

    func decode(_ type: Float.Type) throws -> Float {
        return Float(try decode(Double.self))
    }

    func decode<T>(_ type: T.Type) throws -> T where T : BinaryInteger & Decodable {
        let double = try decode(Double.self)
        guard let value = T(exactly: double) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Unable to decode number to \(T.self)")
            throw DecodingError.typeMismatch(T.self, context)
        }
        return value
    }

    func decode(_ type: Date.Type) throws -> Date {

    }

    func decode(_ type: Data.Type) throws -> Data {

    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = _AMFDecoder(buffer: self.buffer)
        let value = try T(from: decoder)
        /*
         if let nextIndex = decoder.container?.index {
            index = nextIndex
        }
        */
        return value
    }
}
