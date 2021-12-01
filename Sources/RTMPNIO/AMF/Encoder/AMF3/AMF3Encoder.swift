import NIO

final class AMF3Encoder {
    public init() {}

    public func encode(_ value: Encodable) throws -> ByteBuffer {
        let encoder = _AMF3Encoder()

        return encoder.buffer
    }
}

class _AMF3Encoder {
    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    fileprivate var container: _AMF3EncodingContainer?

    let referenceTable = AMF3EncodingReferenceTable()

    var buffer: ByteBuffer {
        return container?.buffer ?? ByteBuffer()
    }
}

protocol _AMF3EncodingContainer {
    var buffer: ByteBuffer { get }
}
