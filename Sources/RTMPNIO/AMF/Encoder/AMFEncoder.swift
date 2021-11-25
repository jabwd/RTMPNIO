//
//  AMFEncoder.swift
//  
//
//  Created by Antwan van Houdt on 12/11/2021.
//

import Foundation
import NIO

final public class AMFEncoder {
    public static let EncodeAsECMAArray: CodingUserInfoKey = CodingUserInfoKey(rawValue: "EncodeAsECMAArray")!

    public init() {}

    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public func encode<T>(_ value: T) throws -> ByteBuffer where T : Encodable {
        return ByteBuffer()
    }
}

protocol _AMFEncodingContainer {
    var buffer: ByteBuffer { get }
}

class _AMFEncoder {
    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    fileprivate var container: _AMFEncodingContainer?

    var buffer: ByteBuffer {
        return container?.buffer ?? ByteBuffer()
    }
}

extension _AMFEncoder: Encoder {
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        precondition(self.container == nil)

        let container = KeyedContainer<Key>(codingPath: self.codingPath, userInfo: userInfo)
        self.container = container

        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        precondition(self.container == nil)

        let container = UnkeyedContainer(codingPath: codingPath, userInfo: userInfo)
        self.container = container

        return container
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        precondition(self.container == nil)

        let container = SingleValueContainer(codingPath: codingPath, userInfo: userInfo)
        self.container = container

        return container
    }
}
