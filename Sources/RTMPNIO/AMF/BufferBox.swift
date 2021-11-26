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

    init(buffer: ByteBuffer) {
        self.buffer = buffer
    }

    // MARK: -

    func moveReaderIndex(to offset: Int) {
        buffer.moveReaderIndex(to: offset)
    }

    var readerIndex: Int {
        buffer.readerIndex
    }

    var writerIndex: Int {
        buffer.writerIndex
    }

    func readByte() -> UInt8? {
        buffer.readBytes(length: 1)?.first
    }

    func readBytes(length: Int) -> [UInt8]? {
        buffer.readBytes(length: length)
    }

    func readInteger<T: FixedWidthInteger>(as: T.Type) -> T? {
        buffer.readInteger(endianness: .big, as: T.self)
    }

    func readString(length: Int) -> String? {
        buffer.readString(length: length)
    }

    func readMarker() -> AMF0TypeMarker? {
        guard let markerByte = readByte() else {
            return nil
        }
        return AMF0TypeMarker(rawValue: markerByte)
    }
}

extension ByteBuffer {
    mutating func readByte() -> UInt8? {
        readBytes(length: 1)?.first
    }

    mutating func readMarker() -> AMF0TypeMarker? {
        guard let byte = readByte() else {
            return nil
        }
        return AMF0TypeMarker(rawValue: byte)
    }
}

extension ByteBuffer {
    mutating func write(byte: UInt8) {
        self.writeBytes([byte])
    }

    mutating func write(marker: AMF0TypeMarker) {
        self.write(byte: marker.rawValue)
    }

    mutating func write(amf3Marker marker: AMF3TypeMarker) {
        self.write(byte: marker.rawValue)
    }
}
