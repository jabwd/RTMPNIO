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

    default:
      break
    }
  }
}
