import NIO

class _AMF3Encoder {
    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    fileprivate var container: _AMFEncodingContainer?
}

protocol _AMF3EncodingContainer {
    var buffer: ByteBuffer { get }
}
