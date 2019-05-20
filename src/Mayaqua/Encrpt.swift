//
//  Encrpt.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/31.
//

import Foundation

//@_silgen_name("Rand")
public func Rand(_ buf: UnsafeMutableRawPointer!, _ size: UINT){
    _ = SecRandomCopyBytes(kSecRandomDefault, Int(size), buf)
}

//@_silgen_name("Rand32")
public func Rand32() -> UINT{
    return UInt32.random(in: 0...UInt32.max)
}
