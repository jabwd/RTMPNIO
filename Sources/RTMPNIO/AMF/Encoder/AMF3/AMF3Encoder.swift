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

    fileprivate var container: AMF3EncodingContainer?

    let referenceTable = AMF3ReferenceTable()

    var buffer: ByteBuffer {
        return container?.buffer ?? ByteBuffer()
    }
}

extension _AMF3Encoder: Encoder {
    func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        precondition(container == nil)

        let container = KeyedContainer<Key>(codingPath: codingPath, userInfo: userInfo, referenceTable: referenceTable)
        self.container = container

        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        precondition(container == nil)

        let container = UnkeyedContainer(codingPath: codingPath, userInfo: userInfo, referenceTable: referenceTable)
        self.container = container

        return container
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        precondition(container == nil)

        let container = SingleValueContainer(codingPath: codingPath, userInfo: userInfo, referenceTable: referenceTable)
        self.container = container

        return container
    }
}

protocol AMF3EncodingContainer {
    var buffer: ByteBuffer { get }
}
