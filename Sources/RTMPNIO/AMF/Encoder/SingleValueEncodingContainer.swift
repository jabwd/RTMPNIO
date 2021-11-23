import NIO
import Foundation

extension _AMFEncoder {
    final class SingleValueContainer {
        private var storage: ByteBuffer = ByteBuffer()

        fileprivate var canEncodeNewValue = true

        fileprivate func checkCanEncode(value: Any?) throws {
            guard self.canEncodeNewValue else {
                let context = EncodingError.Context(codingPath: self.codingPath, debugDescription: "Attempt to encode value through single value container when previously value already encoded.")
                throw EncodingError.invalidValue(value as Any, context)
            }
        }

        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
    }
}

extension _AMFEncoder.SingleValueContainer : SingleValueEncodingContainer {
    func encodeNil() throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(marker: .null)
    }

    func encode(_ value: Bool) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(marker: .boolean)
        storage.write(byte: value ? 1 : 0)
    }

    func encode(_ value: String) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        if value.count > 65535 {
            storage.write(marker: .longString)
            let length = UInt32(value.count)
            storage.writeInteger(length, endianness: .big, as: UInt32.self)
        } else {
            storage.write(marker: .string)
            let length = UInt16(value.count)
            storage.writeInteger(length, endianness: .big, as: UInt16.self)
        }
        storage.writeString(value)
    }

    func encode(_ value: Double) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(marker: .number)
        let value = Int64(bitPattern: value.bitPattern)
        storage.writeInteger(value, endianness: .big, as: Int64.self)
    }

    func encode(_ value: Float) throws {
        try encode(Double(value))
    }

    func encode(_ value: Data) throws {
        let str = value.base64EncodedString()
        try self.encode(str)
    }

    func encode(_ value: Date) throws {

    }

    func encode(_ value: Int) throws {
        try encode(Double(value))
    }

    func encode(_ value: Int8) throws {
        try encode(Double(value))
    }

    func encode(_ value: Int16) throws {
        try encode(Double(value))
    }

    func encode(_ value: Int32) throws {
        try encode(Double(value))
    }

    func encode(_ value: Int64) throws {
        try encode(Double(value))
    }

    func encode(_ value: UInt) throws {
        try encode(Double(value))
    }

    func encode(_ value: UInt8) throws {
        try encode(Double(value))
    }

    func encode(_ value: UInt16) throws {
        try encode(Double(value))
    }

    func encode(_ value: UInt32) throws {
        try encode(Double(value))
    }

    func encode(_ value: UInt64) throws {
        try encode(Double(value))
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        let encoder = _AMFEncoder()
        // try value.encode(to: encoder)
        var buff = encoder.buffer
        storage.writeBuffer(&buff)
    }
}

extension _AMFEncoder.SingleValueContainer : _AMFEncodingContainer {
    var buffer: ByteBuffer {
        storage
    }
}
