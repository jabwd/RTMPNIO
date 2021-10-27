//
//  RTMPPacketDecoder.swift
//  
//
//  Created by Antwan van Houdt on 26/10/2021.
//

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

final class RTMPSession {
  var version: RTMPVersion!
  var clientRandomBytes: [UInt8]?
  var clientEpoch: UInt32 = 0
  let randomBytes: [UInt8]
  var handshake: Handshake

  init() {
    randomBytes = [UInt8].random(bytes: 1528)!
    handshake = Handshake()
  }
}

enum PacketDecodingError: Error {
  case unknownVersion
  case handshakeFailed(reason: String)

  case decodingHeaderFailed

  case notImplemented
}

final class RTMPPacketDecoder: ByteToMessageDecoder {
  public typealias InboundIn = ByteBuffer
  public typealias InboundOut = RTMPPacket

  public let session: RTMPSession
  public var buffer: ByteBuffer?

  /// Stores previously received headers to complete existing received chunk packets from the same chunk stream
  private var knownHeaders: [UInt8: RTMPPacket.Header] = [:]

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
      } else {
        // C0 is one byte, C1 is always 1536 bytes (1528 random bytes + 4b epoch + 4b zero)
        guard buffer.readableBytes >= 1537 else {
          return .needMoreData
        }
        guard let version = RTMPVersion(rawValue: buffer.readInteger(endianness: .little, as: UInt8.self) ?? 0) else {
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

    let basicHeaderByte = buffer.readInteger(endianness: .little, as: UInt8.self) ?? 0

    guard let headerType = HeaderType(rawValue: (basicHeaderByte >> 14) & 0x3) else {
      _ = context.channel.close()
      throw PacketDecodingError.handshakeFailed(reason: "Unable to decode header")
    }
    let chunkStreamID = (basicHeaderByte & 0x3F)
    // TODO: Need to support variable size chunk stream ID encoding still
    print("Rcv pkt: Header=\(headerType), ChunkSID: \(chunkStreamID)")
    if buffer.readableBytes < 11 {
      // Reset the buffer reader so we can re-read the header byte once we get back into this function
      buffer.moveReaderIndex(to: buffer.readerIndex - 1)
      return .needMoreData
    }
    guard let header = decodeHeader(&buffer, type: headerType) else {
      throw PacketDecodingError.decodingHeaderFailed
    }
    let packet = RTMPPacket(type: .rtmp, header: header, chunkStreamID: chunkStreamID)
    let data = self.wrapInboundOut(packet)
    context.fireChannelRead(data)
    return .continue
  }

  private func decodeHeader(_ buffer: inout ByteBuffer, type: HeaderType) -> RTMPPacket.Header? {
    if type == .basic {
      // Means repeated header, should get the other one from somewhere somehow
      return RTMPPacket.Header(messageID: .invalid)
    }

    guard let timestampDeltaBytes = buffer.readBytes(length: 3) else {
      return nil
    }
    let timestampDelta = UInt32(timestampDeltaBytes[0]) | UInt32(timestampDeltaBytes[1]) | UInt32(timestampDeltaBytes[2])
    // Detect extended timestamp:
    if timestampDelta == 0xFFFFFF {
      print("Has extended timestamp, ignoring lol coz i don't care  right now")
      return nil
    }
    if type == .basicAndTimestamp {
      return RTMPPacket.Header(messageID: .invalid, timestampDelta: timestampDelta)
    }
    guard let packetLenBytes = buffer.readBytes(length: 3) else {
      return nil
    }
    guard let messageID = MessageID(rawValue: buffer.readInteger(endianness: .little, as: UInt8.self) ?? 0) else {
      return nil
    }

    let packetLen = UInt32(packetLenBytes[0]) | UInt32(packetLenBytes[1]) | UInt32(packetLenBytes[2])

    if type == .noMessageID {
      return RTMPPacket.Header(messageID: messageID, timestampDelta: timestampDelta, packetLength: packetLen)
    }
    guard let streamID = buffer.readInteger(endianness: .little, as: UInt32.self) else {
      return nil
    }

    return RTMPPacket.Header(
      messageID: messageID,
      timestampDelta: timestampDelta,
      packetLength: packetLen,
      streamID: streamID
    )
  }
}
