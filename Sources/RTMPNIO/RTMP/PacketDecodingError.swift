//
//  PacketDecodingError.swift
//  
//
//  Created by Antwan van Houdt on 25/11/2021.
//

enum PacketDecodingError: Error {
    case needMoreData
    case unknownVersion
    case handshakeFailed(reason: String)
    case dataCorrupted(debugDescription: String)

    case decodingHeaderFailed

    case notImplemented
}
