//
//  AMF3TraitsInfo.swift
//  
//
//  Created by Antwan van Houdt on 01/12/2021.
//

struct AMF3TraitsInfo: Codable, Equatable {
    let className: String
    let dynamic: Bool
    let externalisable: Bool
    let count: UInt32
    let properties: [String]
}
