import NIO

extension _AMF3Encoder {
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

extension _AMF3Encoder.SingleValueContainer {
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
