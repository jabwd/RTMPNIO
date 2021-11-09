//
//  AMFDecoder.swift
//  
//
//  Created by Antwan van Houdt on 09/11/2021.
//

import Foundation
import NIO

enum AMF0TypeMarker: UInt8 {
  case number = 0x00
  case boolean = 0x01
  case string = 0x02
  case object = 0x03
  case movieclip = 0x04
  case null = 0x05
  case undefined = 0x06
  case reference = 0x07
  case ecmaArray = 0x08
  case objectEnd = 0x09
  case strictArray = 0x0A
  case date = 0x0B
  case longString = 0x0C
  case unsupported = 0x0D
  case recordSet = 0x0E
  case xmlDocument = 0x0F
  case typedObject = 0x10
  case switchAMF3 = 0x11
}

enum AMF3TypeMarker: UInt8 {
  case undefined = 0x00
  case null = 0x01
  case boolFalse = 0x02
  case boolTrue = 0x03
  case integer = 0x04
  case double = 0x05
  case string = 0x06
  case xmlDocument = 0x07
  case date = 0x08
  case array = 0x09
  case object = 0x0A
  case xml = 0x0B
  case byteArray = 0x0C

  case vectorInt = 0x0D
  case vectorUInt = 0x0E
  case vectorDouble = 0x0F
  case vectorObject = 0x10
  case dictionary = 0x11
}

enum AMFVersion: UInt16 {
  case amf0 = 0x00
  case amf3 = 0x03
}

final class AMFDecoder {
  var buff: ByteBuffer

  init() {
    buff = ByteBuffer()
  }

  func decode(_ bytes: inout ByteBuffer) -> DecodingState {
    let version = bytes.readInteger(endianness: .big, as: UInt16.self)
    let headerCount = bytes.readInteger(endianness: .big, as: UInt16.self)
    // variable header data
    let messageCount = bytes.readInteger(endianness: .big, as: UInt16.self)
    // variable message data

    return .needMoreData
  }

  private func decodeHeader(_ bytes: inout ByteBuffer, amfVersion: AMFVersion = .amf0) {
    let nameLength = bytes.readInteger(endianness: .big, as: UInt16.self) ?? 0
    let name = bytes.readString(length: Int(nameLength))
    let mustUnderstand = (bytes.readBytes(length: 1)?.first == 1)
    let headerLength = bytes.readInteger(endianness: .big, as: UInt32.self) ?? 0
    var container: [String: Any] = [:]
    let amfPayload = bytes.readSlice(length: Int(headerLength), container: container)
  }

  private func decodeMessage(_ bytes: inout ByteBuffer, amfVersion: AMFVersion = .amf0) {
    let targetURILength = bytes.readInteger(endianness: .big, as: UInt16.self) ?? 0
    let targetURI = bytes.readString(length: Int(targetURILength))
    let responseURILength = bytes.readInteger(endianness: .big, as: UInt16.self) ?? 0
    let responseURI = bytes.readString(length: Int(responseURILength))
    let messageLength = bytes.readInteger(endianness: .big, as: UInt32.self) ?? 0
    let amfPayload = bytes.readSlice(length: Int(messageLength))
  }

  private func decodeAMF(_ bytes: inout ByteBuffer, container: inout [String: Any]) {
    repeat {
      guard let markerByte = bytes.readInteger(endianness: .big, as: UInt8.self),
            let marker = AMF0TypeMarker(rawValue: markerByte) else {
          return
      }
      print("Decoding type \(marker)")
      switch marker {
      case .null,
          .undefined:
        // Do nothing, these don't have trailing data
        break
      case .string:
        let str = decodeString(&bytes) ?? ""
        print("Decoded string: \"\(str)\"")
        break
      case .boolean:
        break
      case .number:
        break
      case .object:
        break
      default:
        break
      }
    } while ( bytes.readableBytes >  0 )
  }

  private func decodeAMF3(_ bytes: inout ByteBuffer) {
    repeat {

    } while ( bytes.readableBytes > 0 )
  }

  // MARK: - Type decoders

  private func decodeString(_ bytes: inout ByteBuffer) -> String? {
    let length = bytes.readInteger(endianness: .big, as: UInt16.self) ?? 0
    return bytes.readString(length: Int(length))
  }
}
