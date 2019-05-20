//
//  Account.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/27.
//

import Foundation
import Mayaqua
// This is actually the Remote Server

extension ACCOUNT{
    static public func setup(_ co:UnsafeMutablePointer<CLIENT_OPTION>, _ ca:UnsafeMutablePointer<CLIENT_AUTH>) -> UnsafeMutablePointer<ACCOUNT> {
        let ptr = salloc(self)
        var rtn = ptr.pointee
        rtn.StartupAccount=true
        rtn.CheckServerCert=false
        rtn.ClientOption=co
        rtn.ClientAuth=ca
        rtn.StatusPrinter=PrintUnicode
        ptr.pointee = rtn
        return ptr
    }
}


func PrintUnicode(s:UnsafeMutablePointer<SESSION>?, status:UnsafeMutablePointer<wchar_t>! ){
//    NSLog("%@", String(decodingCString: UnsafeMutablePointer<UTF32.CodeUnit>(UnsafeMutableRawPointer(status)), as: UTF32.self))
}

@_silgen_name("CiInitConfiguration")
func SCiInitConfiguration(_ c: UnsafeMutablePointer<CLIENT>!){
    
}
