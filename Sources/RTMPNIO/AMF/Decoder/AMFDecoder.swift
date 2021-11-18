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

    public func decodeCommand<T>(_ argument: T.Type, from buffer: inout ByteBuffer) throws -> Command<T> where T : Decodable {
        guard let byte = buffer.readBytes(length: 1)?.first, AMF0TypeMarker(rawValue: byte) == .string else {
            let context = DecodingError.Context.init(codingPath: [], debugDescription: "Unable to decode command name, marker not a string")
            throw DecodingError.dataCorrupted(context)
        }
        guard let length = buffer.readInteger(endianness: .big, as: UInt16.self), let name = buffer.readString(length: Int(length)) else {
            let context = DecodingError.Context.init(codingPath: [], debugDescription: "Unable to decode command name")
            throw DecodingError.dataCorrupted(context)
        }
        /*
         let value = try readInteger(as: UInt64.self)
         return Double(bitPattern: value)
         */
        guard let transMarkerByte = buffer.readBytes(length: 1)?.first, AMF0TypeMarker(rawValue: transMarkerByte) == .number else {
            let context = DecodingError.Context.init(codingPath: [], debugDescription: "Unable to decode command transactionID, not a number marker")
            throw DecodingError.dataCorrupted(context)
        }
        guard let transactionIDValue = buffer.readInteger(endianness: .big, as: UInt64.self) else {
            let context = DecodingError.Context.init(codingPath: [], debugDescription: "Unable to decode command transactionID, unable to read value")
            throw DecodingError.dataCorrupted(context)
        }
        let transactionID = Double(bitPattern: transactionIDValue)
        let decoder = _AMFDecoder(buffer: buffer, referenceTable: [])
        print("Decoding command: \(name):\(transactionID)")
        let value = try T(from: decoder)
        return Command<T>(name: name, transactionID: transactionID, argument: value)
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        let buffer = ByteBuffer(bytes: data)
        let decoder = _AMFDecoder(buffer: buffer, referenceTable: [])
        return try T(from: decoder)
    }
}

final class _AMFDecoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]

    var container: AMFDecodingContainer?
    var referenceTable: [AMFDecodingContainer]

    fileprivate var buffer: ByteBuffer

    init(buffer: ByteBuffer, referenceTable: [AMFDecodingContainer] = []) {
        self.buffer = buffer
        self.referenceTable = referenceTable
    }
}

extension _AMFDecoder : Decoder {
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        print("Decode keyed container")
        precondition(container == nil)

        let container = KeyedContainer<Key>(buffer: buffer, codingPath: codingPath, userInfo: userInfo, referenceTable: referenceTable)
        referenceTable.append(container)
        self.container = container

        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        print("Decode unkeyed container")
        precondition(container == nil)

        let container = UnkeyedContainer(buffer: buffer, codingPath: codingPath, userInfo: userInfo, referenceTable: referenceTable)
        referenceTable.append(container)
        self.container = container

        return container
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        print("Decode single value container")
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
