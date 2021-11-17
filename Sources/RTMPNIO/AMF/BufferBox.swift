//
//  BufferBox.swift
//  
//
//  Created by Antwan van Houdt on 17/11/2021.
//

import NIO

final class BufferBox {
    var buffer: ByteBuffer

    init(_ buffer: inout ByteBuffer) {
        self.buffer = buffer
    }

    // MARK: -
}
