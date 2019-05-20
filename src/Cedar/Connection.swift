//
//  Connection.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/27.
//
//import Darwin
import Foundation
import Mayaqua
import os.signpost

var connectionLog:OSLog = OSLog.init(subsystem: "CedarNetwork", category: "Connection")

extension CLIENT_OPTION{
    static public func setup(_ server:String, _ port:Int,udp:Int = 0,hub:String = "DEFAULT")->UnsafeMutablePointer<CLIENT_OPTION>{
        let ptr = salloc(self)
        var rtn = ptr.pointee
        "VPN".setPtr(&rtn.AccountName)
        server.setPtr(&rtn.Hostname)
        hub.setPtr(&rtn.HubName)
        rtn.Port=UINT32(port)
        rtn.PortUDP=UINT32(udp)
        rtn.UseEncrypt=true
        rtn.MaxConnection=2
        rtn.NoUdpAcceleration=true
        rtn.NumRetry=0
        rtn.AdditionalConnectionInterval=2
        ptr.pointee = rtn
        return ptr
    }
}


extension CLIENT_AUTH{
    
    static public func setup(_ username:String, _ hpasswd:String) -> UnsafeMutablePointer<CLIENT_AUTH> {
        let ptr = salloc(CLIENT_AUTH.self)
        var rtn = ptr.pointee
        rtn.AuthType=UInt32(CLIENT_AUTHTYPE_PLAIN_PASSWORD)
        
        username.setPtr(&rtn.Username)
        hpasswd.setPtr(&rtn.PlainPassword)
        
        ptr.pointee = rtn
        return ptr
    }
    
}

@_silgen_name("NewTcpSock")
func SNewTcpSock(_ s: UnsafeMutablePointer<SOCK>!) -> UnsafeMutablePointer<TCPSOCK>!{
    let ts = InternalNewTcpSock(s)!
    guard TcpSock(ts) != nil else{
        FreeTcpSock(ts)
        return nil
    }
    return ts
}

var cedar:UnsafeMutablePointer<CEDAR>!

public func InitSwiftConnection(_ c:UnsafeMutablePointer<CEDAR>!){
    cedar = c
}

class TcpSock:SwiftSocket{
    static var bufSize:Int { return Int(CedarGetFifoBudgetBalance(cedar)) }
    var inBuf = 0
//    var toRead:Int { return Int(TcpSock.bufSize - inBuf) }
    var pipeWrite:Int32
    var pipeRead:Int32
    var selectEvent = false
    init?(_ tcpSock: UnsafeMutablePointer<TCPSOCK>!) {
        guard let sw:SocketWrapper = GetOpaque(tcpSock?.pointee.Sock.pointee.Param) else{
            return nil
        }
        var pipes:[Int32] = [0,0]
        guard socketpair(PF_LOCAL, SOCK_DGRAM, 0, &pipes) == 0 else {
            return nil
        }
        pipeWrite = pipes[1]
        pipeRead = pipes[0]
        NSLog("TcpSockInit fds: %d, %d", pipeRead,pipeWrite)
        self.tcpSock = tcpSock
        super.init(sw.iSock)
        sw.setISock(self)
    }
    var reading = false

    func read(_ a:Bool = false,_ toRead:Int = bufSize){
        if (a || !reading) && err == nil {
            reading = true
            tcp.readMinimumLength(1, maximumLength: toRead) { data, error in
                self.err = error
                guard let data = data else {
                    return
                }

                self.lock.lock()
                data.withUnsafeBytes { (ptr:UnsafePointer<UInt8>) in
                    LockInner(self.tcpSock.pointee.RecvFifo.pointee.lock)
                    WriteFifo(self.tcpSock.pointee.RecvFifo, UnsafeMutableRawPointer(mutating: ptr), UINT(data.count));
                    UnlockInner(self.tcpSock.pointee.RecvFifo.pointee.lock)
                }


                self.inBuf += data.count
                if !self.selectEvent{
                    Darwin.write(self.pipeWrite,&self.selectEvent,1)
                    self.selectEvent = true
                }


                let space = TcpSock.bufSize - self.inBuf
                self.lock.unlock()


                if space > 0{
                    self.read(true,space)
                }else{
                    self.reading = false
                    NSLog("stop reading")
                }
            }
        }
    }

    override func recv(_: UnsafeMutableRawPointer, _ size: UINT) -> UINT {
        lock.lock()
        defer{
            lock.unlock()
        }
        self.read()
        if inBuf > 0{
            if !self.selectEvent{
                NSLog("Should not reach this")
            }
            let toRead = min(size, UINT(inBuf))
            inBuf -= Int(toRead)
            if inBuf == 0 {
                if Darwin.read(pipeRead,&selectEvent,1) != 1{
                    disconnect()
                    return 0
                }
            }
            s.RecvSize += UINT64(toRead);
            s.RecvNum += 1;
            return toRead
        }
        return !s.Disconnecting ? SOCK_LATER : 0
    }

    let tcpSock:UnsafeMutablePointer<TCPSOCK>!
    override func setup(_ sock : UnsafeMutablePointer<SOCK>) {
        sock.pointee.socket = SOCKET(pipeRead)
    }
}
