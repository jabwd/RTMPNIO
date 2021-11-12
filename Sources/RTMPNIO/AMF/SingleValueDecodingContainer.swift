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
        return ""
    }
}
