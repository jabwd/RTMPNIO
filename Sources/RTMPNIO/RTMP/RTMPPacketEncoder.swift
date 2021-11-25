//
//  RTMPPacketEncoder.swift
//
//
//  Created by Antwan van Houdt on 26/10/2021.
//

import NIO

enum PacketEncodingError: Error {
    case invalidPacket(reason: String)
}

final class RTMPPacketEncoder: MessageToByteEncoder {
    typealias OutboundIn = RTMPPacket
    typealias OutboundOut = ByteBuffer

    func encode(data: RTMPPacket, out: inout ByteBuffer) throws {
        print("Encoder called!?")
        switch data.type {
        case .s0:
            guard let v = data.version else {
                throw PacketEncodingError.invalidPacket(reason: "No version in S0 available")
            }
            out.writeInteger(v.rawValue, endianness: .little, as: UInt8.self)
            break

        case .s1, .s2:
            guard let epoch = data.epoch, let randomBytes = data.randomBytes else {
                throw PacketEncodingError.invalidPacket(reason: "No epoch or randombytes for S1 packet")
            }
            out.writeInteger(epoch, endianness: .little, as: UInt32.self)
            out.writeInteger(0, endianness: .little, as: UInt32.self)
            out.writeBytes(randomBytes)
            break

        case .rtmp:
            try out.writeRTMPHeader(type: .full, chunkStreamID: data.chunkStreamID)
            break

        default:
            break
        }
    }

    private func writeHeader() {
        /*
         if type == .basic {
         return (nil, 0)
         }

         guard let timestampDeltaBytes = buffer.readBytes(length: 3) else {
         return (nil, 0)
         }
         let timestampDelta =
         UInt32(timestampDeltaBytes[0]) | UInt32(timestampDeltaBytes[1]) | UInt32(timestampDeltaBytes[2])
         // Detect extended timestamp:
         if timestampDelta == 0xFFFFFF {
         print("Has extended timestamp, ignoring lol coz i don't care  right now")
         return (nil, 3)
         }
         if type == .basicAndTimestamp {
         if let header = knownHeaders[chunkStreamID] {
         let newHeader = RTMPPacket.Header(
         messageID: header.messageID,
         timestampDelta: timestampDelta,
         packetLength: header.packetLength,
         streamID: header.streamID
         )
         return (newHeader, 3)
         }
         return (RTMPPacket.Header(messageID: .invalid, timestampDelta: timestampDelta), 3)
         }
         guard let packetLenBytes = buffer.readBytes(length: 3) else {
         return (nil, 3)
         }
         guard let messageID = MessageID(rawValue: buffer.readInteger(endianness: .big, as: UInt8.self) ?? 0) else {
         return (nil, 6)
         }

         let packetLen = UInt32(packetLenBytes[0]) | UInt32(packetLenBytes[1]) | UInt32(packetLenBytes[2])

         if type == .noMessageID {
         let header = RTMPPacket.Header(
         messageID: messageID,
         timestampDelta: timestampDelta,
         packetLength: packetLen
         )
         return (header, 7)
         }
         guard let streamID = buffer.readInteger(endianness: .big, as: UInt32.self) else {
         // This really should be a decoding error
         return (nil, 7)
         }
         // A full header should be stored for later reference for the current chunkStreamID
         let header = RTMPPacket.Header(
         messageID: messageID,
         timestampDelta: timestampDelta,
         packetLength: packetLen,
         streamID: streamID
         )
         return (header, 11)
         */
    }
}
