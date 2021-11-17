import NIO

extension _AMFDecoder {
    final class KeyedContainer<Key> where Key : CodingKey {
        var buffer: ByteBuffer
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        var referenceTable: [AMFDecodingContainer]
        var className: String?

        lazy var nestedContainers: [String: AMFDecodingContainer] = {
            return [:]
        }()

        init(buffer: ByteBuffer, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any], referenceTable: [AMFDecodingContainer] = []) {
            self.buffer = buffer
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.referenceTable = referenceTable
        }

        // MARK: -

        func canDecodeValue(forKey key: Key) throws {
            guard contains(key) else {
                let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Key not found \(key)")
                throw DecodingError.keyNotFound(key, context)
            }
        }

        func resolveContainers() throws -> [String: AMFDecodingContainer] {
            do {
                let marker = try readMarker()

                switch marker {
                case .typedObject:
                    let classNameLength = try readInteger(as: UInt16.self)
                    self.className = try readString(length: Int(classNameLength))
                    return nestedContainersForObject()
                case .object:
                    return nestedContainersForObject()
                case .ecmaArray:
                    return nestedContainersForECMAArray()
                default:
                    return [:]
                }
            } catch {
                return [:]
            }
        }

        func nestedCodingPath(forKey key: CodingKey) -> [CodingKey] {
            return codingPath + [key]
        }

        func nestedContainersForObject() -> [String: AMFDecodingContainer] {
            var nestedContainers: [String: AMFDecodingContainer] = [:]

            do {
                var keyLength: UInt16 = try readInteger(as: UInt16.self)
                while keyLength > 0 {
                    let key = try readString(length: Int(keyLength))
                    nestedContainers[key] = readValue(key: key)
                    keyLength = try readInteger(as: UInt16.self)
                }
                let marker = try readMarker()
                guard marker == .objectEnd else {
                    return [:]
                }
            } catch {
                return [:]
            }
            return nestedContainers
        }

        func nestedContainersForECMAArray() -> [String: AMFDecodingContainer] {
            var nestedContainers: [String: AMFDecodingContainer] = [:]

            do {
                let count = try readInteger(as: UInt32.self)

                for _ in 0..<count {
                    let keyLength = try readInteger(as: UInt16.self)
                    let key = try readString(length: Int(keyLength))
                    nestedContainers[key] = readValue(key: key)
                }
                let emptyLength = try readInteger(as: UInt16.self)
                let marker = try readMarker()
                guard emptyLength == 0, marker == .objectEnd else {
                    return [:]
                }
            } catch {
                print("\(error)")
                return [:]
            }
            return nestedContainers
        }

        func readValue(key: String) -> AMFDecodingContainer {
            let unkeyedContainer = UnkeyedContainer(
                buffer: buffer,
                codingPath: codingPath,
                userInfo: userInfo,
                referenceTable: referenceTable
            )

            let keyedContainer = KeyedContainer(
                buffer: buffer,
                codingPath: codingPath,
                userInfo: userInfo,
                referenceTable: referenceTable
            )

            let containers = unkeyedContainer.nestedContainers
            let keyedContainerNestedContainers = keyedContainer.nestedContainers

            if containers.isEmpty && keyedContainerNestedContainers.isEmpty {
                let singleValueContainer = SingleValueContainer(
                    buffer: buffer,
                    codingPath: codingPath,
                    userInfo: userInfo,
                    referenceTable: referenceTable
                )
                return singleValueContainer
            } else if containers.isEmpty == false {
                unkeyedContainer.codingPath += [AnyCodingKey(stringValue: key)!]
                return unkeyedContainer
            } else {
                keyedContainer.codingPath += [AnyCodingKey(stringValue: key)!]
                return keyedContainer
            }
        }
    }
}

extension _AMFDecoder.KeyedContainer : AMFDecodingContainer {}

extension _AMFDecoder.KeyedContainer : KeyedDecodingContainerProtocol {
    var allKeys: [Key] {
        nestedContainers.keys.map { Key(stringValue: $0)! }
    }

    func contains(_ key: Key) -> Bool {
        nestedContainers.keys.contains(key.stringValue)
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        try canDecodeValue(forKey: key)

        guard let singleValueContainer = nestedContainers[key.stringValue] as? _AMFDecoder.SingleValueContainer else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot decode nil for key \(key)")
            throw DecodingError.typeMismatch(Any?.self, context)
        }

        return singleValueContainer.decodeNil()
    }

    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T : Decodable {
        try canDecodeValue(forKey: key)

        guard let container = nestedContainers[key.stringValue] else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Unable to decode nested container for key \(key)")
        }
        let decoder = _AMFDecoder(buffer: container.buffer, referenceTable: referenceTable)

        return try T(from: decoder)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try canDecodeValue(forKey: key)

        guard let unkeyedContainer = nestedContainers[key.stringValue] as? _AMFDecoder.UnkeyedContainer else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Unable to decode nested container for key \(key)")
        }

        return unkeyedContainer
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try canDecodeValue(forKey: key)

        guard let keyedContainer = nestedContainers[key.stringValue] as? _AMFDecoder.KeyedContainer<NestedKey> else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Cannot decode nested keyed conatiner for key \(key)")
        }

        return KeyedDecodingContainer(keyedContainer)
    }

    func superDecoder() throws -> Decoder {
        _AMFDecoder(buffer: buffer, referenceTable: referenceTable)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        let decoder = _AMFDecoder(buffer: buffer, referenceTable: referenceTable)
        decoder.codingPath = [key]

        return decoder
    }
}
