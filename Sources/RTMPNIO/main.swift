import NIO
import NIOPosix
import ArgumentParser

enum HeaderType: UInt8 {
  case full = 0x0
  case noMessageID = 0x1
  case basicAndTimestamp = 0x2
  case basic = 0x3
}

final class RTMPSessionHandler: ChannelInboundHandler {
  public typealias InboundIn = ByteBuffer
  public typealias OutboundOut = ByteBuffer

  public func channelActive(context: ChannelHandlerContext) {
    print("Channel connected")
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let byteBuffer = self.unwrapInboundIn(data)
    let bytes = Array(byteBuffer.readableBytesView)

    let basicHeaderByte = bytes[0]

    guard let headerType = HeaderType(rawValue: (basicHeaderByte >> 14) & 0x3) else {
      print("Unable to decode header type")
      _ = context.channel.close()
      return
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

  public func channelInactive(context: ChannelHandlerContext) {
    print("Channel inactive")
  }
} 

struct RTMPSink: ParsableCommand {
  @Option(name: .shortAndLong, help: "Port number to listen to")
  var port: Int?

  mutating func run() throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    let bootstrap = ServerBootstrap(group: eventLoopGroup)
    .serverChannelOption(ChannelOptions.backlog, value: 256)
    .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelInitializer { channel in
      return channel.pipeline.addHandler(RTMPSessionHandler())
    }

    defer {
      try! eventLoopGroup.syncShutdownGracefully()
    }

    let defaultHost = "0.0.0.0"
    let defaultPort = port ?? 1935
    
   let channel = try bootstrap.bind(host: defaultHost, port: defaultPort).wait()
   guard let localAddress = channel.localAddress else {
     fatalError("Address was unable to bind")
   }
   print("RTMPNIO Server listening on \(localAddress)")

   try channel.closeFuture.wait()
  }
}

RTMPSink.main()
print("RTMPNIO Shut down cleanly")
