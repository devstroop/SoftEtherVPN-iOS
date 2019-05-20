//
//  Session.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/27.
//

import Foundation
import NetworkExtension
import Mayaqua

extension SESSION{
    static public func setup(_ opt:UnsafeMutablePointer<CLIENT_OPTION>, _ auth:UnsafeMutablePointer<CLIENT_AUTH>, _ pa:UnsafeMutablePointer<PACKET_ADAPTER>, _ account:UnsafeMutablePointer<ACCOUNT>)->UnsafeMutablePointer<SESSION>{
//        let ptr = UnsafeMutablePointer<SESSION>.allocate(capacity: 1)
        let ptr = salloc(self)
        var rtn = ptr.pointee
        NSLog("\(UnsafeMutablePointer(&rtn))")
        rtn.Account=account
        rtn.ClientOption=opt
        rtn.ClientAuth=auth
        rtn.PacketAdapter=pa
        rtn.MaxConnection = opt.pointee.MaxConnection
        rtn.UseEncrypt = opt.pointee.UseEncrypt
        rtn.UseCompress = opt.pointee.UseCompress
        rtn.lock = Lock.CNewLock()
        rtn.TrafficLock = Lock.CNewLock()
        rtn.HaltEvent = Event.CNewEvent()
        
        // Cedar
        rtn.Cedar=NewCedar(nil, nil)
//        rtn.Cedar.pointee.CurrentTcpQueueSizeLock = Lock.CNewLock()
//        rtn.Cedar.pointee.FifoBudgetLock = Lock.CNewLock()
//        rtn.Cedar.pointee.QueueBudgetLock = Lock.CNewLock()
//        rtn.Cedar.pointee.lock = Lock.CNewLock()
//        rtn.Cedar.pointee.TrafficLock = Lock.CNewLock()
//        rtn.Cedar.pointee.Client=salloc(CLIENT.self)
        ptr.pointee = rtn
        return ptr
    }
}

