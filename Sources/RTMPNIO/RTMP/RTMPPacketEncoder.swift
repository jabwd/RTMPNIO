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
            // Our size is currently always set to a max of 128bytes
            let packet = data
            let maxSndSize = 128
            let chunks = Int(ceil(Double(packet.length) / Double(maxSndSize)))
            var buff = packet.body ?? ByteBuffer()
            for n in 0..<chunks {
                let type: HeaderType
                if n == 0 {
                    type = .full
                } else {
                    type = .basic
                }
                try out.writeRTMPHeader(type: type, chunkStreamID: packet.chunkStreamID)
                writeHeader(type: type, header: packet.header, buffer: &out)
                var length = maxSndSize
                if buff.readableBytes < length {
                    length = buff.readableBytes
                }
                if var chunk = buff.readSlice(length: length) {
                    out.writeBuffer(&chunk)
                    print("Written packet with body of size \(chunk.readableBytes)")
                }

            }
            break

        default:
            break
        }
    }

    private func writeHeader(type: HeaderType, header: RTMPPacket.Header, buffer: inout ByteBuffer) {
        if type == .basic {
            return
        }
        // Figure out how to do the timestamp delta
        buffer.writeBytes([0, 0, 0])

        if let packetLength = header.packetLength {
            let ptr = Swift.withUnsafeBytes(of: packetLength.bigEndian) { unsafeRawPtr in
                return unsafeRawPtr.dropLast()
            }
            print("Count: \(ptr.count)")
            buffer.writeBytes(ptr)
        }
        buffer.writeInteger(header.messageID.rawValue, endianness: .big, as: UInt8.self)

        if let streamID = header.streamID {
            buffer.writeInteger(streamID, endianness: .big, as: UInt32.self)
        }
    }
}
