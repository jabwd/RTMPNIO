//
//  AMFMarker.swift
//  
//
//  Created by Antwan van Houdt on 17/11/2021.
//

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
