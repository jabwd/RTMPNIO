import NIO
import Foundation

extension _AMFEncoder {
    final class UnkeyedContainer {
        private var storage: [_AMFEncodingContainer] = []

        var count: Int {
            storage.count
        }

        var codingPath: [CodingKey]

        var nestedCodingPath: [CodingKey] {
            return codingPath + [AnyCodingKey(intValue: self.count)]
        }

        var userInfo: [CodingUserInfoKey: Any]

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
    }
}

extension _AMFEncoder.UnkeyedContainer {
    func encodeNil() throws {
        
    }
}
