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

  /// Version request sent in the C0 at the beginning of the handshake
  var version: RTMPVersion?

  /// Random bytes sent by the client during the C1 packet of the handshake
  var randomBytes: [UInt8]?

  /// Epoch received from the client during the C1 packet of the handshake
  /// or our epoch for validation during the C2 packet of the handshake
  var epoch: UInt32?

  init(
    type: PacketType,
    version: RTMPVersion? = nil,
    randomBytes: [UInt8]? = nil,
    epoch: UInt32? = nil
  ) {
    self.type = type
    self.version = version
    self.randomBytes = randomBytes
    self.epoch = epoch
  }
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

  case notImplemented
}

final class RTMPPacketDecoder: ByteToMessageDecoder {
  public typealias InboundIn = ByteBuffer
  public typealias InboundOut = RTMPPacket

  public let session: RTMPSession
  public var buffer: ByteBuffer?

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
        guard let readEpoch = buffer.readInteger(endianness: .little, as: UInt32.self) else {
          throw PacketDecodingError.handshakeFailed(reason: "Cant decode read epoch from client2")
        }
        print("Read at: \(readEpoch)")

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
    } else {
      print("Received a regular RTMP packet, probably. I can't hadle this yet so BYEEE")
      let bytes = Array(buffer.readableBytesView)

      let basicHeaderByte = bytes[0]

      guard let headerType = HeaderType(rawValue: (basicHeaderByte >> 14) & 0x3) else {
        _ = context.channel.close()
        throw PacketDecodingError.handshakeFailed(reason: "Unable to decode header")
      }
      let chunkStreamID = (basicHeaderByte & 0x3F)
      print("Rcv pkt: Header=\(headerType), ChunkSID: \(chunkStreamID)")
      switch headerType {
      case .full:
        // We skip the first byte since we decoded that above already
        decodeFullHeader(slice: bytes[1..<12])
        break
      default:
        print("Unhandled header type: \(headerType)")
        _ = context.channel.close()
        break
      }
    }
    return .needMoreData
  }

  private func decodeFullHeader(slice: ArraySlice<UInt8>) {
    // We have 11 bytes remaining if everything is going according to plan
    precondition(slice.count == 11, "Decoding full header requires 11 bytes to be present in the slice")

    // let timestampDelta = slice[slice.startIndex..<(slice.startIndex+3)]
    let packetLength = slice[(slice.startIndex+3)..<(slice.startIndex+6)]
    let packetLen = UInt32(packetLength[packetLength.startIndex]) | UInt32(packetLength[packetLength.startIndex+1]) | UInt32(packetLength[packetLength.startIndex+2])
    let messageTypeID = slice[slice.startIndex+6]
    let streamID = slice[(slice.startIndex+7)..<slice.startIndex+11]
    print("streamID: \(streamID.count)")
    let streamIDT = UInt32(streamID[8]) | UInt32(streamID[9]) | UInt32(streamID[10]) | UInt32(streamID[11])
    print("Packet len: \(packetLen), messageType: \(messageTypeID), streamID: \(streamIDT)")
  }
}
