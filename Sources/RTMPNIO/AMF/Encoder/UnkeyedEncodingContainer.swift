import NIO
import Foundation

extension _AMFEncoder {
    final class UnkeyedContainer {
        private var storage: [_AMFEncodingContainer] = []

        var count: Int {
            storage.count
        }

        var codingPath: [CodingKey]

        var nestedCodingPath: [CodingKey] {
            return codingPath + [AnyCodingKey(intValue: self.count)!]
        }

        var userInfo: [CodingUserInfoKey: Any]

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
    }
}

extension _AMFEncoder.UnkeyedContainer : UnkeyedEncodingContainer {
    func encodeNil() throws {
        var container = self.nestedSingleValueContainer()
        try container.encodeNil()
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        var container = self.nestedSingleValueContainer()
        try container.encode(value)
    }

    private func nestedSingleValueContainer() -> SingleValueEncodingContainer {
        let container = _AMFEncoder.SingleValueContainer(codingPath: nestedCodingPath, userInfo: userInfo)
        storage.append(container)

        return container
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = _AMFEncoder.KeyedContainer<NestedKey>(codingPath: nestedCodingPath, userInfo: userInfo)
        storage.append(container)

        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = _AMFEncoder.UnkeyedContainer(codingPath: nestedCodingPath, userInfo: userInfo)
        storage.append(container)

        return container
    }

    func superEncoder() -> Encoder {
        fatalError("Not implemented")
    }
}

extension _AMFEncoder.UnkeyedContainer : _AMFEncodingContainer {
    var buffer: ByteBuffer {
        var buffer = ByteBuffer()

        buffer.write(marker: .strictArray)
        buffer.writeInteger(UInt32(storage.count), endianness: .big, as: UInt32.self)
        for container in storage {
            var buff = container.buffer
            buffer.writeBuffer(&buff)
        }
        return buffer
    }
}
