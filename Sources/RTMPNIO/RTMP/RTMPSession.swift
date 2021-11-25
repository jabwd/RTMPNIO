//
//  RTMPSession.swift
//  
//
//  Created by Antwan van Houdt on 25/11/2021.
//

final class RTMPSession {
    var version: RTMPVersion!
    var clientRandomBytes: [UInt8]?
    var clientEpoch: UInt32 = 0
    let randomBytes: [UInt8]
    var handshake: Handshake

    var receiveChunkSize: Int = 128
    var sendChunkSize: Int = 128

    init() {
        randomBytes = [UInt8].random(bytes: 1528)!
        handshake = Handshake()
    }
}
