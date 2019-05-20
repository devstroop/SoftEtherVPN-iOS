//
//  IPC.swift
//  Cedar
//
//  Created by Gentoli on 2019-02-05.
//

import Foundation
import Mayaqua
import NetworkExtension
import os.signpost
import Darwin
//.disabled //
var PoI:OSLog = .disabled //OSLog.init(subsystem: "event", category: .pointsOfInterest)
var ipcLog:OSLog = .disabled //OSLog.init(subsystem: "Network", category: "Connection")

var swiftPacketAdapter:SwiftPacketAdapter!
public func GenPacketAdapter(_ spa:SwiftPacketAdapter) -> UnsafeMutablePointer<PACKET_ADAPTER>{
    swiftPacketAdapter = spa
    let ptr = salloc(PACKET_ADAPTER.self)
    var pa = PACKET_ADAPTER()
    pa.Init = { s in
        if swiftPacketAdapter == nil{
            return false
        }
        return swiftPacketAdapter.ipcInit(s)
    }
    pa.GetCancel = { s in
        return swiftPacketAdapter.getCancel()
    }
    pa.GetNextPacket = { s,pack in
        return swiftPacketAdapter.getNextPacket(pack)
    }
    pa.PutPacket = { (s:UnsafeMutablePointer<SESSION>?, pack: UnsafeMutableRawPointer?, size: UINT) -> Bool in
        return swiftPacketAdapter.putPacket(pack, size)
    }
    pa.Free = { (s:UnsafeMutablePointer<SESSION>?) in
        swiftPacketAdapter.free()
        swiftPacketAdapter = nil
    }
    pa.Param = UnsafeMutableRawPointer(ToOpaque(swiftPacketAdapter))
    ptr.pointee = pa
    return ptr
}

public class SwiftPacketAdapter : Thread{
    // L3 IPC <--> iOS
    //    var internalConnection:NEPacketTunnelFlow
    var tunnel:NEPacketTunnelProvider
    
    var sock:SOCK
    let mac = UnsafeMutablePointer<UCHAR>.allocate(capacity: 6)
    let tunFd:Int32
    
    var i: UnsafeMutablePointer<IPC>!
    var state:NWTCPConnectionState = .invalid
    
    public init(_ tunnel:NEPacketTunnelProvider) {
        //        self.internalConnection = tunnel.packetFlow
        self.tunnel = tunnel
        GenMacAddress(mac)
        
        tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32
        
        l3Buf = buf.advanced(by: 4)
        l3Proto = buf.assumingMemoryBound(to: UInt32.self)
        
        var tIPCRecv:UnsafeMutablePointer<TUBE>!
        var tIPCSend:UnsafeMutablePointer<TUBE>!
        NewTubePair(&tIPCSend,&tIPCRecv,0)
        let sock = NewInProcSocket(tIPCSend,tIPCRecv)!
        self.sock = sock.pointee
        Free(sock)
        
        super.init()
        
        self.sock.Param = UnsafeMutableRawPointer(ToOpaque(self))
        
        name = "IPC PacketAdapter"
        super.qualityOfService = .userInteractive
        super.threadPriority = 1
    }
    
    func upgradeCancel(){
        if !cancel.pointee.SpecialFlag {
            UnixSetSocketNonBlockingMode(tunFd,true)
            UnixDeletePipe(cancel.pointee.pipe_read, cancel.pointee.pipe_write)
            cancel.pointee.pipe_write = -1
            cancel.pointee.SpecialFlag = true
            cancel.pointee.pipe_read = tunFd
        }
    }
    
    func ipcInit(_ s:UnsafeMutablePointer<SESSION>!) -> Bool {
        i = NewIPCBySock(s.pointee.Cedar,&sock,mac)
        if i == nil{
            return false
        }
        state = .connecting
        start()
        mac.deallocate()
        return true
    }
    
    let ipcProcessDS = DispatchSemaphore(value: 0)
    var processing = true
    static let mtu = 1400
    static let bufSize = mtu + 4
    // L2 -> L3 SwiftPacketAdapter -> IPC
    override public func main() {
        var cao = DHCP_OPTION_LIST()
        var ip = IP()
        var subnet = IP()
        var gw = IP()
        if(!IPCDhcpAllocateIP(i, &cao, nil)){
            return
        }
        UINTToIP(&ip, cao.ClientAddress);
        UINTToIP(&subnet, cao.SubnetMask);
        UINTToIP(&gw, cao.Gateway);

//        "192.168.0.123".withCString { (ptr)  in
//            StrToIP(&ip,UnsafeMutablePointer(mutating:ptr))
//        }
//        "255.255.255.0".withCString { (ptr)  in
//            StrToIP(&subnet,UnsafeMutablePointer(mutating:ptr))
//        }
//        "192.168.0.1".withCString { (ptr)  in
//            StrToIP(&gw,UnsafeMutablePointer(mutating:ptr))
//        }
        
        IPCSetIPv4Parameters(i, &ip, &subnet, &gw,&cao.ClasslessRoute);
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.168.0.11")
        
        settings.ipv4Settings = NEIPv4Settings(
            addresses: [ip.toString()],
            subnetMasks: [subnet.toString()])
        
        settings.ipv4Settings!.includedRoutes = [NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0")]
        
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1","8.8.8.8"])
        
        settings.mtu = SwiftPacketAdapter.mtu as NSNumber
        
        tunnel.setTunnelNetworkSettings(settings){ err in
            defer{
                self.ipcProcessDS.signal()
            }
            if let e = err{
                self.state = .disconnected
                self.free()
                return
            }
            NSLog("---------------connected--------------")
            self.state = .connected
        }
        ipcProcessDS.wait()
        ReleaseQueue(ipc.IPv4ReceivedQueue)
        ipc.IPv4ReceivedQueue = nil
        upgradeCancel()
    }
    
    var ipcProcess = OSSignpostID.init(log: ipcLog)
    
    //    var l2PackToSoftEther = LinkedListHead<Block>()
    var l2PackToSoftEtherL = NSLock()
    // L2 SwiftPacketAdapter -> SoftEther
    let buf = malloc(SwiftPacketAdapter.bufSize)!
    let l3Buf:UnsafeMutableRawPointer
    let l3Proto:UnsafeMutablePointer<UInt32>
    var l2Buf:UnsafeMutableRawPointer?
    var l2Size:UINT = 0
    let l2Ds = DispatchSemaphore(value: 1)
    func getNextPacket(_ pack: UnsafeMutablePointer<UnsafeMutableRawPointer?>!) -> UINT {
        if l2Buf == nil{
            // recv tun
            let l3Size = read(tunFd, buf, SwiftPacketAdapter.bufSize)
            if l3Size < 4 || l3Proto.pointee != SwiftPacketAdapter.AFINET{
                return 0
            }
            // translate
            IPCSendIPv4(self.i, l3Buf, UINT(l3Size - 4)) // -> IPCSendL2
        }
        
        // send
        guard let l2Buf = l2Buf else {
            return 0
        }
        defer {
            self.l2Buf = nil
            l2Ds.signal()
        }
        pack.pointee = l2Buf
        return l2Size
    }
    
    @_silgen_name("IPCSendL2")
    public static func SIPCSendL2(_ ipc: UnsafeMutablePointer<IPC>!, _ pack: UnsafeMutableRawPointer!, _ size: UINT){
        guard let swiftPa:SwiftPacketAdapter = GetPacketAdapter(ipc) else{
            return
        }
        swiftPa.l2Ds.wait()
        swiftPa.l2Size = size
        swiftPa.l2Buf = Clone(pack, size)
        if !swiftPa.cancel.pointee.SpecialFlag {
            Cancel(swiftPa.cancel)
        }
    }
    
    //    var l2PackToIPC = LinkedListHead<UnsafeMutablePointer<BLOCK>>()
    var l2PackToIPCL = NSLock()
    //    let flowSendDQ = DispatchQueue(label: "Send")
    // L2 SoftEther -> SwiftPacketAdapter
    var packBuf:UnsafeMutablePointer<BLOCK>?
    func putPacket(_ pack: UnsafeMutableRawPointer!, _ size: UINT) -> Bool { // IPCSendL2
        guard let pack = pack else{
            return isActive()
        }
        os_signpost(.event, log: PoI, name: "Tun", "->SwiftPacketAdapter")
        packBuf = NewBlock(pack, size, 0)
        IPCProcessL3Events(i) // -> IPCPutL3
        return isActive()
    }
    
    static let AFINET = CFSwapInt32HostToBig(UInt32(AF_INET))
    
    @_silgen_name("IPCPutL3")
    public static func SIPCPutL3(_ ipc: UnsafeMutablePointer<IPC>!,_ pack: UnsafeMutableRawPointer!, _ size: UINT){
        guard let swiftPa:SwiftPacketAdapter = GetPacketAdapter(ipc) else{
            return
        }
        let start = pack.advanced(by: -4)
        let count = Int(size + 4)
        start.assumingMemoryBound(to: UInt32.self).pointee = AFINET
        if write(swiftPa.tunFd, start, count) != count{
            swiftPa.state = .disconnected
        }
    }
    
    @_silgen_name("IPCRecvL2")
    public static func SIPCRecvL2(_ ipc: UnsafeMutablePointer<IPC>!) -> UnsafeMutablePointer<BLOCK>!{
        guard let swiftPa:SwiftPacketAdapter = GetPacketAdapter(ipc) else{
            return nil
        }
        defer {
            swiftPa.packBuf = nil
        }
        return swiftPa.packBuf
    }
    
    
    var cancel = NewCancel()!
    func getCancel() ->  UnsafeMutablePointer<CANCEL>? {
        return cancel
    }
    func free(){
        state = .disconnected
        ipcProcessDS.signal()
    }
    
    func isActive() -> Bool {
        return !(state == .invalid || state == .disconnected)
    }
    
    fileprivate static func GetPacketAdapter(_ ipc: UnsafeMutablePointer<IPC>!) -> SwiftPacketAdapter? {
        return GetOpaque(ipc.pointee.Sock.pointee.Param)
    }
    
    var ipc:IPC {
        get{
            return i.pointee
        }
        set{
            i.pointee = newValue
        }
    }
    struct Block {
        let buf:UnsafeMutableRawPointer
        let size:UINT
        init(copy buf:UnsafeMutableRawPointer, _ size:UINT) {
            self.buf = Clone(buf, size)
            self.size = size
        }
    }
}

public extension IP{
    mutating func toString() -> String {
        let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: 128)
        
        withUnsafeMutablePointer(to: &self) { ipPtr in
            IPToStr(ptr, 128, ipPtr)
        }
        
        let rtn = String(cString: ptr)
        ptr.deallocate()
        return rtn
    }
}
