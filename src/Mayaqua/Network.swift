//
//  Network.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/30.
//

import Foundation
import NetworkExtension
import os.signpost


var tunnel:NEPacketTunnelProvider! = nil
// .disabled //
var PoI:OSLog = OSLog.init(subsystem: "event", category: .pointsOfInterest)
var networkLog:OSLog = OSLog.init(subsystem: "Network", category: "Connection")
public func InitSwiftNetwork(_ provider:NEPacketTunnelProvider){
    tunnel = provider
}

@_silgen_name("s_socket")
public func s_socket(_: Int32, _: Int32, _: Int32) -> Int32{
    return INVALID_SOCKET
}

@_silgen_name("s_close")
public func s_close(_ fd: Int32) -> Int32{
    //    let fd = Int(fd)
    //    sockets[fd]!.disconnect()
    //    sockets[fd] = nil
    return 0
}

@_silgen_name("ConnectEx4")
public func SConnectEx4(_ hostname: UnsafeMutablePointer<Int8>!, _ port: UINT, _ timeout: UINT, _ cancel_flag: UnsafeMutablePointer<Bool>!, _ nat_t_svc_name: UnsafeMutablePointer<Int8>!, _ nat_t_error_code: UnsafeMutablePointer<UINT>!, _ try_start_ssl: Bool, _ no_get_hostname: Bool, _ ret_ip: UnsafeMutablePointer<IP>!) -> UnsafeMutablePointer<SOCK>!{
    let s = SwiftSocket(hostname, port, timeout, cancel_flag)
    return SocketWrapper(s).sock
}

@_silgen_name("Recv")
public func SRecv(_ sock: UnsafeMutablePointer<SOCK>!, _ data: UnsafeMutableRawPointer!, _ size: UINT, _ secure: Bool) -> UINT{
    guard let sock:SocketWrapper = GetOpaque(sock.pointee.Param) else{
        return 0
    }
    return sock.recv(data,size)
}

@_silgen_name("Send")
public func SSend(_ sock: UnsafeMutablePointer<SOCK>!, _ data: UnsafeMutableRawPointer!, _ size: UINT, _ secure: Bool) -> UINT{
    guard let sock:SocketWrapper = GetOpaque(sock.pointee.Param) else{
        return 0
    }
    return sock.send(data,size)
}

public protocol PSwiftSocket:AnyObject{
    func recv(_: UnsafeMutableRawPointer, _: UINT) -> UINT
    func send(_: UnsafeMutableRawPointer, _: UINT) -> UINT
    func setup(_: UnsafeMutablePointer<SOCK>)->Void
    func disconnect()->Void
}
extension PSwiftSocket{
    public func setup(_ :UnsafeMutablePointer<SOCK>)->Void { }
}

public class SocketWrapper:PSwiftSocket {
    public var iSock:SwiftSocket
    public var sock = NewSock()!
    
    init(_ iSock: SwiftSocket) {
        self.iSock = iSock
        setISock(iSock)
    }
    
    public func setISock(_ iSock: SwiftSocket) {
        self.iSock = iSock
        iSock.setup(sock)
        sock.pointee.Param = ToOpaque(self)
    }
    
    public func send(_ buf:UnsafeMutableRawPointer, _ size:UINT) -> UINT{
        return iSock.send(buf,size)
    }
    
    public func recv(_ buf:UnsafeMutableRawPointer, _ size:UINT) -> UINT{
        return iSock.recv(buf,size)
    }
    
    public func disconnect() {
        iSock.disconnect()
    }
}


open class SwiftSocket: NSObject,PSwiftSocket {
    public var tcp:NWTCPConnection!
    public var endPoint:NWHostEndpoint
    public let lock = NSLock()
    public var err:Error?
    public let timeout:Int
    public var sock:UnsafeMutablePointer<SOCK>
    
    public init(_ old:SwiftSocket) {
        tcp = old.tcp
        endPoint = old.endPoint
        timeout = old.timeout
        err = old.err
        sock = old.sock
    }
    
    init(_ hostname: UnsafeMutablePointer<Int8>!,_ port: UINT,_ timeout: UINT, _ cancel_flag: UnsafeMutablePointer<Bool>!) {
        self.endPoint = NWHostEndpoint(hostname: String(cString: hostname), port: String(port))
        self.timeout = Int(timeout)
        sock = NewSock()!
        super.init()
        
        tcp = tunnel.createTCPConnection(to: endPoint, enableTLS: true, tlsParameters: nil, delegate: self)
        tcp.addObserver(self, forKeyPath: "state", options: .initial, context: &tcp)
        recvDS.wait()
    }
    
    let recvDS = DispatchSemaphore(value: 0)
    var recvSP = OSSignpostID.init(log: networkLog)
    open func recv(_ buf:UnsafeMutableRawPointer, _ size:UINT) -> UINT {
        var size = Int(size)
        var ptr = buf.assumingMemoryBound(to: UInt8.self)
        var read = 0
        
        os_signpost(.begin, log: networkLog, name: "Recv",signpostID:recvSP,"want %d",size)
        defer {
            os_signpost(.end, log: networkLog, name: "Recv",signpostID:recvSP,"got %d",read)
        }
        
        if error != nil {
            return 0
        }
        defer {
            s.RecvSize+=UINT64(read)
            s.RecvNum+=1
        }
        
        
        lock.lock()
        tcp.readMinimumLength(1, maximumLength: size) { (data, err) in
            defer{
                self.recvDS.signal()
            }
            
            guard let data = data else{
                self.error = err
                return
            }
            
            data.withUnsafeBytes { (dat:UnsafePointer<UInt8>) in
                ptr.assign(from: dat, count: data.count)
                read = data.count
            }
        }
        lock.unlock()
        recvDS.wait()
        
        return UINT(read)
    }
    
    let sendDS = DispatchSemaphore(value: 1)
    open func send(_ data:UnsafeMutableRawPointer, _ size:UINT) -> UINT {
        
        let sendSP = OSSignpostID.init(log: networkLog,object: NSObject())
        
        os_signpost(.begin, log: networkLog, name: "Send", signpostID: sendSP,"%d",size)
        
        let s_data = Data(bytes: data, count:  Int(size))
        
        if let e = self.error{
            NSLog(e.localizedDescription)
            Disconnect(sock)
            return 0
        }
        
        sendDS.wait()
        self.tcp.write(s_data) { (e) in
            self.error = e
            self.sendDS.signal()
            os_signpost(.end, log: networkLog, name: "Send", signpostID: sendSP)
        }
        
        s.SendSize+=UInt64(size)
        s.SendNum+=1
        return size
    }
    
    public func disconnect() {
        
    }
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "state" else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        //        tcp.value(forKey: "state")
        NSLog("Connected %d: \(tcp.state)",s.socket)
        switch tcp.state {
        case .connected:
            s.Connected = true;
            let a = tcp.propertyNames()
            print(a)
            recvDS.signal()
        case .connecting:
            break
        case .disconnected:
            s.Connected = false;
            tcp.cancel()
            fallthrough
        default:
            break
        }
    }
    
    open func setup(_ sock : UnsafeMutablePointer<SOCK>) {
        sock.pointee = self.sock.pointee
        Free(self.sock)
        self.sock = sock
    }
    
    public var s:SOCK{
        get{
            return sock.pointee
        }
        set{
            if sock != nil{
                sock.pointee = newValue
            }
        }
    }
    
    var error:Error?{
        get{
            return err
        }
        set{
            if let err = newValue{
                self.err = err
                s.Connected = false
            }
        }
    }
    
}

@_silgen_name("StartSSLEx")
public func SStartSSLEx(_ sock: UnsafeMutablePointer<SOCK>!, _ x: UnsafeMutablePointer<X>!, _ priv: UnsafeMutablePointer<K>!, _ ssl_timeout: UINT, _ sni_hostname: UnsafeMutablePointer<Int8>!) -> Bool{
    sock.pointee.RemoteX = UnsafeMutablePointer<X>.init(bitPattern: 1)
    return true
}

extension SwiftSocket:NWTCPConnectionAuthenticationDelegate{
    public func evaluateTrust(for connection: NWTCPConnection, peerCertificateChain: [Any], completionHandler completion: @escaping (SecTrust) -> Void){
        var optionalTrust: SecTrust?
        //        var policyTrust: SecPolicy?
        
        _ = SecTrustCreateWithCertificates([peerCertificateChain[0]] as CFTypeRef, nil, &optionalTrust)
        
        completion(optionalTrust!)
    }
}

public class CancelObj {
    public init(){}
    public var action:(()->Any)?
    public var str:String?
    public var set = false
    public var setToggle = false
    public static func RegisterCancel(_ c: UnsafeMutablePointer<CANCEL>!, _ cond: (()->Any)?){
        guard let cancel:CancelObj = GetOpaque(c) else {
            return
        }
        cancel.action = cond
        //        if cancel.set {
        ////            os_signpost(.event, log: PoI, name: "CancelObj", "Set")
        //            CancelObj.SCancel(c)
        //        }
    }
    
    //    @_silgen_name("NewCancel")
    public static func SNewCancel() -> UnsafeMutablePointer<CANCEL>!{
        return ToOpaque(CancelObj())
    }
    
    //    @_silgen_name("ReleaseCancel")
    public static func SReleaseCancel(_ c: UnsafeMutablePointer<CANCEL>!){
        ReleaseOpaque(c)
    }
    
    public static func SUnCancel(_ c: UnsafeMutablePointer<CANCEL>!){
        guard let cancel:CancelObj = GetOpaque(c) else {
            return
        }
        cancel.setToggle = true
        cancel.set = false
    }
    
    //    @_silgen_name("Cancel")
    public static func SCancel(_ c: UnsafeMutablePointer<CANCEL>!){
        guard let cancel:CancelObj = GetOpaque(c) else {
            return
        }
        if let act = cancel.action{
            act()
            os_signpost(.event, log: PoI, name: "Select","Cancel")
            if !cancel.setToggle{
                cancel.set = false
            }
        }
        if cancel.setToggle{
            cancel.set = true
        }
        
    }
}

extension NSObject {
    //
    // Retrieves an array of property names found on the current object
    // using Objective-C runtime functions for introspection:
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
    //
    func propertyNames() -> Array<String> {
        var results: Array<String> = [];
        // retrieve the properties via the class_copyPropertyList function
        var count: UInt32 = 0;
        var myClass: AnyClass = self.classForCoder;
        var properties = class_copyPropertyList(myClass, &count)!;
        // iterate each objc_property_t struct
        for i in 0...count-1 {
            var property = properties[Int(i)];
            // retrieve the property name by calling property_getName function
            var cname = property_getName(property);
            // covert the c string into a Swift string
            var name = String(cString:cname);
            results.append(name);
        }
        // release objc_property_t structs
        free(properties);
        return results;
    }
}
