import NIO

final class AMF3Decoder {
    func decode<T>(_: T.Type, from buffer: ByteBuffer) throws -> T where T: Decodable {
        fatalError("Not implemented")
    }
}

final class _AMF3Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var container: AMF3DecodingContainer?
    fileprivate var buffer: ByteBuffer
    let referenceTable: AMF3ReferenceTable

    init(buffer: ByteBuffer, referenceTable: AMF3ReferenceTable) {
        self.buffer = buffer
        self.referenceTable = referenceTable
    }
}

protocol AMF3DecodingContainer {
    var buffer: ByteBuffer {
        get set
    }
}
