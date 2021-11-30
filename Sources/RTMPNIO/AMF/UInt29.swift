//
//  UInt29.swift
//  
//
//  Created by Antwan van Houdt on 30/11/2021.
//

import NIO

enum UInt29Error: Error {
    case integerTooLarge
}

extension UInt32 {
    init(uint29 buffer: inout ByteBuffer) {
        self = Self.decodeUInt29(&buffer)
    }

    static func decodeUInt29(_ buffer: inout ByteBuffer) -> UInt32 {
        var value: UInt32 = 0
        var byte = buffer.readByte() ?? 0x0

        // First 3 bytes can have the MSB set to indicate that another byte is following
        // for the 29 bit integer
        if byte & 0x80 == 0 {
            return UInt32(byte)
        }
        value = UInt32(byte & 0x7F) << 7
        byte = buffer.readByte() ?? 0x0

        // 14bits
        if byte & 0x80 == 0 {
            return value | UInt32(byte)
        }
        value = (value | UInt32(byte & 0x7F)) << 7
        byte = buffer.readByte() ?? 0x0

        // 21
        if byte & 0x80 == 0 {
            return value | UInt32(byte)
        }
        value = (value | UInt32(byte & 0x7F)) << 8
        byte = buffer.readByte() ?? 0x0
        value |= UInt32(byte)

        return value
    }

    func uint29Representation() throws -> ByteBuffer {
        guard self <= 0x1F_FF_FF_FF else {
            throw UInt29Error.integerTooLarge
        }

        var buffer = ByteBuffer()

        if self < 0x80 {
            buffer.writeInteger(UInt8(self), endianness: .big, as: UInt8.self)
            return buffer
        }

        if self < 0x4000 {
            let bytes: [UInt8] = [
                (UInt8(self >> 7 & 0x7F) | 0x80),
                UInt8(self & 0x7F)
            ]
            buffer.writeBytes(bytes)
            return buffer
        }

        if self < 0x20_00_00 {
            let bytes: [UInt8] = [
                (UInt8(self >> 14 & 0x7F) | 0x80),
                (UInt8(self >> 7 & 0x7F) | 0x80),
                UInt8(self & 0x7F)
            ]
            buffer.writeBytes(bytes)
            return buffer
        }

        // The ranges are increased from 7 bits to 8 etc. because we're encoding big endian
        // and the last byte is 8bits in this encoding scheme.
        // Therefore all the previous bits need to be moved by 22 15 and 8 instead of 7.
        let bytes: [UInt8] = [
            (UInt8(self >> 22 & 0x7F) | 0x80),
            (UInt8(self >> 15 & 0x7F) | 0x80),
            (UInt8(self >> 8 & 0x7F) | 0x80),
            UInt8(self & 0xFF)
        ]
        buffer.writeBytes(bytes)

        return buffer
    }
}
