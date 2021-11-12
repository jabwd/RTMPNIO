//
//  AMFDecoder2.swift
//  
//
//  Created by Antwan van Houdt on 11/11/2021.
//

import Foundation
import NIO

final public class AMFDecoder2 {
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
    fileprivate var data: Data

    init(data: Data) {
        self.data = data
    }
}

protocol AMFDecodingContainer: AnyObject {
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

    func readMarker() throws -> AMF0TypeMarker {
        guard let marker = AMF0TypeMarker(rawValue: try readByte()) else {
            let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unknown type marker")
            throw DecodingError.dataCorrupted(context)
        }
        return marker
    }
}
