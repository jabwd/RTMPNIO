//
//  BufferBox.swift
//  
//
//  Created by Antwan van Houdt on 17/11/2021.
//

import NIO

enum BufferBoxError: Error {
    case outOfBytes
}

final class BufferBox {
    var buffer: ByteBuffer

    init(_ buffer: inout ByteBuffer) {
        self.buffer = buffer
    }

    // MARK: -

    func readByte() throws -> UInt8 {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            throw BufferBoxError.outOfBytes
        }
        return byte
    }

    func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        guard let value = buffer.readInteger(endianness: .big, as: T.self) else {
            throw BufferBoxError.outOfBytes
        }
        return value
    }

    func readString(length: Int) throws -> String {
        guard let value = buffer.readString(length: length) else {
            throw BufferBoxError.outOfBytes
        }
        return value
    }

    func readMarker() throws -> AMF0TypeMarker {
        guard let marker = AMF0TypeMarker(rawValue: try readByte()) else {
            throw BufferBoxError.outOfBytes
        }
        return marker
    }
}
