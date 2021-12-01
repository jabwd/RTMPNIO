import Foundation
import NIO

extension _AMF3Encoder {
    final class KeyedContainer<Key> where Key: CodingKey {
        private var storage: [AnyCodingKey: AMF3EncodingContainer] = [:]

        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        let referenceTable: AMF3EncodingReferenceTable

        func nestedCodingPath(forKey key: CodingKey) -> [CodingKey] {
            codingPath + [key]
        }

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any], referenceTable: AMF3EncodingReferenceTable) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.referenceTable = referenceTable
        }


    }
}

extension _AMF3Encoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encodeNil(forKey key: Key) throws {
        var container = nestedSingleValueContainer(forKey: key)
        try container.encodeNil()
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        let container = _AMF3Encoder.SingleValueContainer(codingPath: nestedCodingPath(forKey: key), userInfo: userInfo, referenceTable: referenceTable)
        try container.encode(value)
    }

    private func nestedSingleValueContainer(forKey key: Key) -> SingleValueEncodingContainer {
        let container = _AMF3Encoder.SingleValueContainer(codingPath: nestedCodingPath(forKey: key), userInfo: userInfo, referenceTable: referenceTable)
        storage[AnyCodingKey(key)] = container

        return container
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let container = _AMF3Encoder.UnkeyedContainer(codingPath: nestedCodingPath(forKey: key), userInfo: userInfo, referenceTable: referenceTable)
        storage[AnyCodingKey(key)] = container

        return container
    }

    func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let container = _AMF3Encoder.KeyedContainer<NestedKey>(codingPath: nestedCodingPath(forKey: key), userInfo: userInfo, referenceTable: referenceTable)
        storage[AnyCodingKey(key)] = container

        return KeyedEncodingContainer(container)
    }

    func superEncoder() -> Encoder {
        fatalError("Not implemented")
    }

    func superEncoder(forKey key: Key) -> Encoder {
        fatalError("not implemented")
    }
}

extension _AMF3Encoder.KeyedContainer: AMF3EncodingContainer {
    var buffer: ByteBuffer {
        var buffer = ByteBuffer()

        buffer.write(amf3Marker: .object)

        // Traits info

        for (key, container) in storage {
            // dynamic traits
            fatalError("Notimplemented fully eyt")

            var buff = container.buffer
            buffer.writeBuffer(&buff)
        }

        buffer.writeBytes([0x1])

        return buffer
    }
}
