import ArgumentParser
import NIO
import NIOPosix

import Foundation

enum HeaderType: UInt8 {
    case full = 0x0
    case noMessageID = 0x1
    case basicAndTimestamp = 0x2
    case basic = 0x3
}

final class RTMPSessionHandler: ChannelInboundHandler {
    public typealias InboundIn = RTMPPacket
    public typealias OutboundOut = RTMPPacket

    public let session: RTMPSession

    init(session: RTMPSession) {
        self.session = session
    }

    public func channelActive(context: ChannelHandlerContext) {
        print("Channel connected")
    }

    private func send(packet: RTMPPacket, context: ChannelHandlerContext) {
        let data = self.wrapOutboundOut(packet)
        _ = context.writeAndFlush(data)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = self.unwrapInboundIn(data)

        switch packet.type {
        case .c0:
            session.handshake.c0 = true
            session.handshake.s0 = true
            session.version = packet.version ?? .v3
            send(packet: RTMPPacket(type: .s0, version: .v3), context: context)
            break

        case .c1:
            session.handshake.c1 = true
            session.handshake.s1 = true
            session.handshake.s2 = true
            let s1 = RTMPPacket(type: .s1, randomBytes: session.randomBytes, epoch: 0)
            send(packet: s1, context: context)
            let s2 = RTMPPacket(type: .s2, randomBytes: packet.randomBytes, epoch: packet.epoch)
            session.clientRandomBytes = packet.randomBytes
            session.clientEpoch = packet.epoch ?? 0
            send(packet: s2, context: context)
            break

        case .c2:
            session.handshake.c2 = true
            break

        case .rtmp:
            print("Channel rcv: \(packet.header.messageID), packetLen: \(String(describing: packet.header.packetLength))")
            if packet.messageID == .setPacketSize && packet.bodyCount == 4 {
                guard var body = packet.body else {
                    return
                }
                let newSize = (body.readInteger(endianness: .big, as: UInt32.self) ?? 0) & 0x7F_FF_FF_FF
                session.receiveChunkSize = Int(newSize)
                print("Session size updated to \(newSize)")
                return
            }
            if var body = packet.body {
                let decoder = AMFDecoder()
                do {
                    let command = try decoder.decodeCommand(ConnectCommand.self, from: &body)
                    print("Command: \(command)")
                } catch {
                    print("\(error)")
                }
//                let decoder = AMFDecoder()
//                var buffer = ByteBuffer(bytes: body)
//                do {
//                    let command = try decoder.decodeCommand(ConnectCommand.self, from: &buffer)
//                    print("Command: \(command)")
//                } catch {
//                    print("\(error)")
//                }

//                let decoder = RawAMFDecoder()
//                var buffer = body
//                _ = decoder.decode(&buffer)
            }
            break

        default:
            print("Received unhandled packet type: \(packet.type)")
            break
        }
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
                let session = RTMPSession()
                return channel.pipeline.addHandlers([
                    ByteToMessageHandler(RTMPPacketDecoder(session: session)),
                    MessageToByteHandler(RTMPPacketEncoder()),
                ]).flatMap { v in
                    channel.pipeline.addHandler(RTMPSessionHandler(session: session))
                }
            }
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

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
