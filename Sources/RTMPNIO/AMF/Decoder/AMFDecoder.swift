//
//  AMFDecoder.swift
//  
//
//  Created by Antwan van Houdt on 11/11/2021.
//

import Foundation
import NIO

final public class AMFDecoder {
    public init() {}

    /**
     A dictionary you use to customize the decoding process
     by providing contextual information.
     */
    public var userInfo: [CodingUserInfoKey : Any] = [:]

    // public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
    //     switch type {
    //         case is Data.Type:
    //         let box = try Box<Data>(from: decoder)
    //     }
    // }
}

final class _AMFDecoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]

    var container: AMFDecodingContainer?
    var referenceTable: [AMFDecodingContainer]

    fileprivate var buffer: BufferBox

    init(buffer: ByteBuffer, referenceTable: [AMFDecodingContainer] = []) {
        self.buffer = buffer
        self.referenceTable = referenceTable
    }
}

extension _AMFDecoder : Decoder {
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        precondition(container == nil)

        let container = KeyedContainer<Key>(buffer: buffer, codingPath: codingPath, userInfo: userInfo, referenceTable: referenceTable)
        referenceTable.append(container)
        self.container = container

        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        precondition(container == nil)

        let container = UnkeyedContainer(buffer: buffer, codingPath: codingPath, userInfo: userInfo, referenceTable: referenceTable)
        referenceTable.append(container)
        self.container = container

        return container
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        precondition(container == nil)

        let container = SingleValueContainer(buffer: buffer, codingPath: codingPath, userInfo: userInfo, referenceTable: referenceTable)
        self.container = container
        return container
    }

}

protocol AMFDecodingContainer : AnyObject {
    var codingPath: [CodingKey] { get set }
    var userInfo: [CodingUserInfoKey : Any] { get }

    var buffer: ByteBuffer { get set }
}

extension AMFDecodingContainer {
    func readByte() throws -> UInt8 {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unexpected end of data")
            throw DecodingError.dataCorrupted(context)
        }
        return byte
    }

    func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        guard let value = buffer.readInteger(endianness: .big, as: T.self) else {
            let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unexpected end of data")
            throw DecodingError.dataCorrupted(context)
        }
        return value
    }

    func readString(length: Int) throws -> String {
        guard let value = buffer.readString(length: length) else {
            let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: "unexpected end of data while reading string")
            throw DecodingError.dataCorrupted(context)
        }
        return value
    }

    func readMarker() throws -> AMF0TypeMarker {
        guard let marker = AMF0TypeMarker(rawValue: try readByte()) else {
            let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unknown type marker")
            throw DecodingError.dataCorrupted(context)
        }
        return marker
    }
}
