//
//  File.swift
//
//
//  Created by Antwan van Houdt on 27/10/2021.
//

import NIO

enum PacketType {
    case c0
    case s0
    case c1
    case s1
    case c2
    case s2

    case rtmp
}

struct RTMPPacket {
    let type: PacketType
    let header: Header
    let chunkStreamID: UInt32

    /// Version request sent in the C0 at the beginning of the handshake
    var version: RTMPVersion?

    /// Random bytes sent by the client during the C1 packet of the handshake
    var randomBytes: [UInt8]?

    /// Epoch received from the client during the C1 packet of the handshake
    /// or our epoch for validation during the C2 packet of the handshake
    var epoch: UInt32?

    var body: ByteBuffer?

    var messageID: MessageID {
        return header.messageID
    }

    var length: Int {
        return Int(header.packetLength ?? 0)
    }

    var bodyCount: Int {
        return body?.readableBytes ?? 0
    }

    init(
        type: PacketType,
        header: Header? = nil,
        chunkStreamID: UInt32 = 0,
        version: RTMPVersion? = nil,
        randomBytes: [UInt8]? = nil,
        epoch: UInt32? = nil,
        body: ByteBuffer? = nil
    ) {
        self.type = type
        if let header = header {
            self.header = header
        }
        else {
            self.header = Header(messageID: .invalid)
        }
        self.chunkStreamID = chunkStreamID
        self.version = version
        self.randomBytes = randomBytes
        self.epoch = epoch
        self.body = body
    }
}

extension RTMPPacket {
    struct Header {
        let messageID: MessageID
        let timestampDelta: UInt32?
        let packetLength: UInt32?
        let streamID: UInt32?

        init(
            messageID: MessageID,
            timestampDelta: UInt32? = nil,
            packetLength: UInt32? = nil,
            streamID: UInt32? = nil
        ) {
            self.messageID = messageID
            self.timestampDelta = timestampDelta
            self.packetLength = packetLength
            self.streamID = streamID
        }
    }
}
