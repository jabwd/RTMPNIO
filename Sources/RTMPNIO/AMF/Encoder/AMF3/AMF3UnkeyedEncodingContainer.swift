import Foundation
import NIO

extension _AMF3Encoder {
    final class UnkeyedContainer {
        private var storage: [AMF3EncodingContainer] = []

        var count: Int {
            storage.count
        }

        var nestedCodingPath: [CodingKey] {
            codingPath + [AnyCodingKey(intValue: self.count)!]
        }

        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        let referenceTable: AMF3ReferenceTable

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any], referenceTable: AMF3ReferenceTable) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.referenceTable = referenceTable
        }
    }
}

// UnkeyedEncodingContainer
extension _AMF3Encoder.UnkeyedContainer: UnkeyedEncodingContainer {
    func encodeNil() throws {
        var container = nestedSingleValueContainer()
        try container.encodeNil()
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        var container = nestedSingleValueContainer()
        try container.encode(value)
    }

    private func nestedSingleValueContainer() -> SingleValueEncodingContainer {
        let container = _AMF3Encoder.SingleValueContainer(codingPath: nestedCodingPath, userInfo: userInfo, referenceTable: referenceTable)
        storage.append(container)
        return container
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = _AMF3Encoder.UnkeyedContainer(codingPath: nestedCodingPath, userInfo: userInfo, referenceTable: referenceTable)
        storage.append(container)

        return container
    }

    func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = _AMF3Encoder.KeyedContainer<NestedKey>(codingPath: nestedCodingPath, userInfo: userInfo, referenceTable: referenceTable)
        storage.append(container)

        return KeyedEncodingContainer(container)
    }

    func superEncoder() -> Encoder {
        fatalError("Not implemented")
    }
}

extension _AMF3Encoder.UnkeyedContainer: AMF3EncodingContainer {
    var buffer: ByteBuffer {
        var buffer = ByteBuffer()

        buffer.write(amf3Marker: .array)
        var countAndRefFlag = try! UInt32(storage.count << 1 | 1).uint29Representation()
        buffer.writeBuffer(&countAndRefFlag)

        buffer.writeBytes([
            0x01
        ])

        storage.forEach { container in
            var buff = container.buffer
            buffer.writeBuffer(&buff)
        }

        return buffer
    }
}
