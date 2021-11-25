import Foundation
import NIO

extension _AMFEncoder {
    final class KeyedContainer<Key> where Key : CodingKey {
        private var storage: [AnyCodingKey: _AMFEncodingContainer] = [:]

        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]

        func nestedCodingPath(forKey key: CodingKey) -> [CodingKey] {
            return self.codingPath + [key]
        }

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
    }
}

extension _AMFEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encodeNil(forKey key: Key) throws {
        var container = self.nestedSingleValueContainer(forKey: key)
        try container.encodeNil()
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        var container = nestedSingleValueContainer(forKey: key)
        try container.encode(value)
    }

    private func nestedSingleValueContainer(forKey key: Key) -> SingleValueEncodingContainer {
        let container = _AMFEncoder.SingleValueContainer(codingPath: nestedCodingPath(forKey: key), userInfo: userInfo)
        storage[AnyCodingKey(key)] = container
        return container
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let container = _AMFEncoder.UnkeyedContainer(codingPath: codingPath, userInfo: userInfo)
        storage[AnyCodingKey(key)] = container
        return container
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = _AMFEncoder.KeyedContainer<NestedKey>(codingPath: nestedCodingPath(forKey: key), userInfo: userInfo)
        storage[AnyCodingKey(key)] = container
        return KeyedEncodingContainer(container)
    }

    func superEncoder() -> Encoder {
        fatalError("Not implemented")
    }

    func superEncoder(forKey key: Key) -> Encoder {
        fatalError("Not implemented")
    }
}

extension _AMFEncoder.KeyedContainer : _AMFEncodingContainer {
    var buffer: ByteBuffer {
        var buffer = ByteBuffer()

        // TODO: Option for encoding as an ECMAArray
        let isEcmaArray = false

        if isEcmaArray {
            buffer.write(marker: .ecmaArray)

            let count = UInt32(storage.count)
            buffer.writeInteger(count, endianness: .big, as: UInt32.self)
            let sorted = storage.sorted(by: { (lh, rh) -> Bool in
                lh.key.stringValue > rh.key.stringValue
            })
            for item in sorted {
                let length = UInt16(item.key.stringValue.count)
                buffer.writeInteger(length, endianness: .big, as: UInt16.self)
                buffer.writeString(item.key.stringValue)
                var valueBuff = item.value.buffer
                buffer.writeBuffer(&valueBuff)
            }
        } else {
            buffer.write(marker: .object)

            for (key, container) in storage {
                let length = UInt16(key.stringValue.count)
                buffer.writeInteger(length, endianness: .big, as: UInt16.self)
                buffer.writeString(key.stringValue)
                var valueBuff = container.buffer
                buffer.writeBuffer(&valueBuff)
            }
        }

        // Both these end markers work for both types, object and ecma array
        buffer.writeInteger(0, endianness: .big, as: UInt16.self)
        buffer.write(marker: .objectEnd)

        return buffer
    }
}
