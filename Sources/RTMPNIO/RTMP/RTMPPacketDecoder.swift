//
//  RTMPPacketDecoder.swift
//
//
//  Created by Antwan van Houdt on 26/10/2021.
//

import Foundation
import NIO

enum RTMPVersion: UInt8 {
    // 1-2 are no longer supported or something
    // this entire type is pointless.
    // I hate adobe.
    case v3 = 0x3
    // 4-35 is reserved
}

struct Handshake {
    var c0: Bool
    var c1: Bool
    var c2: Bool

    var s0: Bool
    var s1: Bool
    var s2: Bool

    init() {
        c0 = false
        c1 = false
        c2 = false

        s0 = false
        s1 = false
        s2 = false
    }

    var completed: Bool {
        return c0 && c1 && c2 && s0 && s1 && s2
    }
}

extension Data {
  struct HexEncodingOptions: OptionSet {
    let rawValue: Int
    static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
  }

  func hexEncodedString(options: HexEncodingOptions = []) -> String {
    let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
    return self.map { String(format: format, $0) }.joined()
  }
}

extension ByteBuffer {
    mutating func readRTMPHeader() throws -> (HeaderType, UInt32) {
        let byte = readInteger(endianness: .big, as: UInt8.self) ?? 0

        guard let headerType = HeaderType(rawValue: (byte >> 6)) else {
            throw PacketDecodingError.decodingHeaderFailed
        }

        var chunkStreamID: UInt32 = UInt32(byte & 0x3F)
        switch chunkStreamID {
            // 2 Byte variant
        case 0:
            guard let bytes = readBytes(length: 1) else {
                throw PacketDecodingError.needMoreData
            }
            chunkStreamID |= UInt32(bytes[0])
            break

            // 3 Byte variant
        case 1:
            guard let bytes = readBytes(length: 2) else {
                throw PacketDecodingError.needMoreData
            }
            chunkStreamID = chunkStreamID | UInt32(bytes[0]) | UInt32(bytes[1])
            break

            // 2-63 chunkStreamID can be kept as-is, so we do nothing here
        default:
            break
        }
        return (headerType, chunkStreamID)
    }

    mutating func writeRTMPHeader(type: HeaderType, chunkStreamID: UInt32) throws {
        let typeBits: UInt8 = (type.rawValue & 0x3) << 6
        let chunkBits: UInt8 = UInt8(chunkStreamID & 0x3F)

        if chunkStreamID > 1 && chunkStreamID < 64 {
            let byte = UInt8(typeBits | chunkBits)
            writeBytes([byte])
            return
        } else if chunkStreamID > 65535 {
            fatalError("Not implemented")
        } else {
            fatalError("Large chunkStreamID not implemented")
        }
    }
}

final class RTMPPacketDecoder: ByteToMessageDecoder {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = RTMPPacket

    public let session: RTMPSession
    public var buffer: ByteBuffer?

    /// Stores previously received headers to complete existing received chunk packets from the same chunk stream
    private var knownHeaders: [UInt32: RTMPPacket.Header] = [:]
    private var unfinishedPackets: [UInt32: RTMPPacket] = [:]

    init(session: RTMPSession) {
        self.session = session
    }

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // Step one: receive c0 and c1 together (usually)
        // we are allowed to wait for c0 and c1 before we act on anything.
        // Since we have c0 and c1 we also reply with S0, S1 and S2 right after which we can expect
        // to receive C2 finally.

        // Detect handshake mode specifically
        if session.handshake.completed == false {
            if session.handshake.c0 && session.handshake.c1 {
                guard let ourEpoch = buffer.readInteger(endianness: .little, as: UInt32.self) else {
                    throw PacketDecodingError.handshakeFailed(reason: "Cant decode epoch from client")
                }

                // I currently don't give a flying fuck about this one
                //        guard let readEpoch = buffer.readInteger(endianness: .little, as: UInt32.self) else {
                //          throw PacketDecodingError.handshakeFailed(reason: "Cant decode read epoch from client2")
                //        }
                buffer.moveReaderIndex(forwardBy: 4)

                guard let ourRandomBytes = buffer.readBytes(length: 1528) else {
                    throw PacketDecodingError.handshakeFailed(reason: "Unable to read randomBytes from client")
                }

                let c1 = RTMPPacket(
                    type: .c2,
                    randomBytes: ourRandomBytes,
                    epoch: ourEpoch
                )
                context.fireChannelRead(self.wrapInboundOut(c1))
                return .continue
            }
            else {
                // C0 is one byte, C1 is always 1536 bytes (1528 random bytes + 4b epoch + 4b zero)
                guard buffer.readableBytes >= 1537 else {
                    return .needMoreData
                }
                guard let version = RTMPVersion(rawValue: buffer.readInteger(endianness: .little, as: UInt8.self) ?? 0)
                else {
                    throw PacketDecodingError.unknownVersion
                }
                let c0 = RTMPPacket(
                    type: .c0,
                    version: version
                )
                context.fireChannelRead(self.wrapInboundOut(c0))

                // Scan the contents of C1
                guard let epoch = buffer.readInteger(endianness: .little, as: UInt32.self) else {
                    throw PacketDecodingError.handshakeFailed(reason: "Cant decode epoch from client")
                }

                // Skip the zeroes, since they seem to have to be zeros but clients ignoore this /shrug
                buffer.moveReaderIndex(forwardBy: 4)
                guard let randomBytes = buffer.readBytes(length: 1528) else {
                    throw PacketDecodingError.handshakeFailed(reason: "Unable to read randomBytes from client")
                }

                let c1 = RTMPPacket(
                    type: .c1,
                    randomBytes: randomBytes,
                    epoch: epoch
                )
                context.fireChannelRead(self.wrapInboundOut(c1))
                return .continue
            }
        }

        let startIndex = buffer.readerIndex
        let (headerType, chunkStreamID) = try buffer.readRTMPHeader()
        print("HeaderType: \(headerType), ChunkStreamID: \(chunkStreamID)")
        if headerType == .basic {
            if var packet = unfinishedPackets[chunkStreamID] {
                let missingBytes = packet.length - packet.bodyCount
                guard missingBytes > 0 else {
                    throw PacketDecodingError.dataCorrupted(debugDescription: "Negative missing bytes detected, this should never happen")
                }
                let readableBytes = buffer.readableBytes

                if missingBytes <= readableBytes {
                    guard var chunk = buffer.readSlice(length: missingBytes) else {
                        throw PacketDecodingError.dataCorrupted(debugDescription: "Unable to read chunk of size \(missingBytes) for aggregated body")
                    }
                    packet.body?.writeBuffer(&chunk)
                    let data = self.wrapInboundOut(packet)
                    unfinishedPackets[chunkStreamID] = nil
                    context.fireChannelRead(data)
                    return .continue
                } else if readableBytes >= session.receiveChunkSize {
                    guard var chunk = buffer.readSlice(length: session.receiveChunkSize) else {
                        throw PacketDecodingError.dataCorrupted(debugDescription: "Unable to read chunk of size \(session.receiveChunkSize) for aggregated body")
                    }
                    packet.body?.writeBuffer(&chunk)
                    unfinishedPackets[chunkStreamID] = packet

                    // Packet is not done here, so we wait for more data
                    return .needMoreData
                } else {
                    // We don't have enough data to complete reading the packet or there is not enough data
                    // to read the set chunk size for this session, so we simply stop, return and wait for more data
                    buffer.moveReaderIndex(to: startIndex)
                    return .needMoreData
                }
            } else {
                // I don't think this should technically happen, but i don't know how to handle it right now
                print("No previously known packet found, basic header is probably an error")
                buffer.moveReaderIndex(to: startIndex)
                return .needMoreData
            }
        }

        // TODO: Probably don't need the byteCount field here anymore
        let headerResult = decodeHeader(&buffer, chunkStreamID: chunkStreamID, type: headerType)
        guard let header = headerResult.0 else {
            print("Decoding header failed")
            throw PacketDecodingError.decodingHeaderFailed
        }

        // Determine whether we have a body to read!
        var body: ByteBuffer?
        let length = Int(header.packetLength ?? 0)
        if length > 0 {
            print("Length: \(length)")
            let byteCount = length > session.receiveChunkSize ? session.receiveChunkSize : length
            print("ByteCount: \(byteCount)")
            body = buffer.readSlice(length: byteCount)
        }
        let packet = RTMPPacket(
            type: .rtmp,
            header: header,
            chunkStreamID: chunkStreamID,
            body: body
        )

        if packet.length > packet.bodyCount {
            print("Need more packet body data still, saving for later")
            unfinishedPackets[chunkStreamID] = packet
            print("Readable bytes left: \(buffer.readableBytes) \(buffer.readerIndex)")
            return .continue
        }

        // If we fall through here the packet should be finished and ready to be decoded further
        let data = self.wrapInboundOut(packet)
        context.fireChannelRead(data)
        return .continue
    }

    private func decodeHeader(_ buffer: inout ByteBuffer, chunkStreamID: UInt32, type: HeaderType) -> (RTMPPacket.Header?, Int) {
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
    }
}
