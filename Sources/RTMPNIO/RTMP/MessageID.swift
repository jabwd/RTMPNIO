//
//  MessageID.swift
//  
//
//  Created by Antwan van Houdt on 25/11/2021.
//

enum MessageID: UInt8 {
    case invalid = 0x0
    case setPacketSize = 0x1
    case abort = 0x2
    case ack = 0x3
    case control = 0x4
    case serverBandwidth = 0x5
    case clientBandwidth = 0x6
    case virtualControl = 0x7
    case audio = 0x8
    case video = 0x9
    case dataExtended = 0xF
    case containerExtended = 0x10
    case amf3 = 0x11
    case data = 0x12
    case container = 0x13
    case amf0 = 0x14
    case udp = 0x15
    case aggregate = 0x16
    case present = 0x17
}
