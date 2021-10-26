//
//  RandomBytes.swift
//
//
//  Created by Antwan van Houdt on 18/01/2021.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif
import Foundation

extension Array where Element == UInt8 {
  // TODO: Figure out why the fuck CryptoKit has no random number primitive
  // We could include libbsd to use arc4random on linux, but can't be bothered
  // with the dependency hell that library gives you right now
  // besides, /dev/urandom is good enough on modern OS' anyway.

  // This implementation will horribly break when using /dev/random in an ubuntu based container
  static func random(bytes: Int) -> [UInt8]? {
    guard let fd = fopen("/dev/urandom", "r") else {
      return nil
    }
    defer { fclose(fd) }
    var buff: [UInt8] = [UInt8](repeating: 0, count: bytes)
    let len = fread(&buff, 1, buff.count, fd)
    guard len == buff.count else {
      return nil
    }
    return buff
  }
}

extension Data {
  static func random(bytes: Int) -> Data? {
    guard let random = Array<UInt8>.random(bytes: bytes) else {
      return nil
    }
    return Data(random)
  }
}
