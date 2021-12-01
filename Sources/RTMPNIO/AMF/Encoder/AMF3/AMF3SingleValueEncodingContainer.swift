import NIO
import Foundation

extension _AMF3Encoder {
    final class SingleValueContainer: AMF3EncodingContainer {
        private var storage: ByteBuffer = ByteBuffer()

        fileprivate var canEncodeNewValue = true

        var buffer: ByteBuffer {
            get {
                storage
            }
        }

        fileprivate func checkCanEncode(value: Any?) throws {
            guard self.canEncodeNewValue else {
                let context = EncodingError.Context(codingPath: self.codingPath, debugDescription: "Attempt to encode value through single value container when previously value already encoded.")
                throw EncodingError.invalidValue(value as Any, context)
            }
        }

        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        let referenceTable: AMF3EncodingReferenceTable

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any], referenceTable: AMF3EncodingReferenceTable) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.referenceTable = referenceTable
        }
    }
}

extension _AMF3Encoder.SingleValueContainer : SingleValueEncodingContainer {
    func encodeNil() throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(amf3Marker: .null)
    }

    func encode(_ value: Bool) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(amf3Marker: value ? .boolTrue : .boolFalse)
    }

    func encode(_ value: String) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(amf3Marker: .string)
        var length = try UInt32(value.count).uint29Representation()
        storage.writeBuffer(&length)
        storage.writeString(value)
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        let encoder = _AMF3Encoder()
        try value.encode(to: encoder)
        var buff = encoder.buffer
        storage.writeBuffer(&buff)
    }

    func encode(_ value: Data) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(amf3Marker: .byteArray)
        var length = try UInt32(value.count).uint29Representation()
        storage.writeBuffer(&length)
        storage.writeBytes(value)
    }

    func encode(_ value: Date) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        let dateValue = value.timeIntervalSince1970 * 1000
        storage.write(amf3Marker: .date)
        storage.writeInteger(dateValue.bitPattern, endianness: .big, as: UInt64.self)
    }

    func encode(_ value: Double) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(amf3Marker: .double)
        storage.writeInteger(value.bitPattern, endianness: .big, as: UInt64.self)
    }

    func encode(_ value: Float) throws {
        try encode(Double(value))
    }

    func encode(_ value: UInt8) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(amf3Marker: .integer)
        var buff = try UInt32(value).uint29Representation()
        storage.writeBuffer(&buff)
    }

    func encode(_ value: UInt16) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        storage.write(amf3Marker: .integer)
        var buff = try UInt32(value).uint29Representation()
        storage.writeBuffer(&buff)
    }

    func encode(_ value: UInt32) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        do {
            var buff = try value.uint29Representation()
            storage.write(amf3Marker: .integer)
            storage.writeBuffer(&buff)
        } catch {
            try encode(Double(value))
        }
    }

    func encode(_ value: UInt64) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        let v = Double(bitPattern: value)
        try encode(v)
    }

    func encode(_ value: Int8) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        try encode(Double(value))
    }

    func encode(_ value: Int16) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        try encode(Double(value))
    }

    func encode(_ value: Int32) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        try encode(Double(value))
    }

    func encode(_ value: Int64) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        try encode(Double(value))
    }

    func encode(_ value: Int) throws {
        try checkCanEncode(value: nil)
        defer { self.canEncodeNewValue = false }

        try encode(Double(value))
    }
}
