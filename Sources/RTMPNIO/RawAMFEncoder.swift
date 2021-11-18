//
//  RawAMFEncoder.swift
//  
//
//  Created by Antwan van Houdt on 18/11/2021.
//

import NIO

public enum RawAMFObjectValue {
    case number(Double)
    case string(String)
}

final class RawAMFEncoder {
    private var buffer: ByteBuffer

    init() {
        buffer = ByteBuffer()
    }

    // MARK: -

    private func encode(_ marker: AMF0TypeMarker) {
        let byte = marker.rawValue
        buffer.writeBytes([byte])
    }

    // MARK: -

    func encodeNull() {
        encode(.null)
    }

    func encodeUndefined() {
        encode(.undefined)
    }

    func encode(_ value: String) {
        if value.count > 65535 {
            encode(.longString)
            buffer.writeInteger(UInt32(value.count), endianness: .big, as: UInt32.self)
        } else {
            encode(.string)
            buffer.writeInteger(UInt16(value.count), endianness: .big, as: UInt16.self)
        }
        buffer.writeString(value)
    }

    func encode(_ value: Double) {
        encode(.number)
        let value = Int64(bitPattern: value.bitPattern)
        buffer.writeInteger(value, endianness: .big, as: Int64.self)
    }

    func encode<T>(_ value: T) where T : BinaryInteger & Decodable {
        let v = Double(value)
        encode(v)
    }
}
