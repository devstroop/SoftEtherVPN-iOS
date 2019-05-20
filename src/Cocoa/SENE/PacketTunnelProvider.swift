//
//  PacketTunnelProvider.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/19.
//

import NetworkExtension
import Mayaqua
import Cedar
import os.signpost

let poi:OSLog = OSLog.init(subsystem: "server", category: .pointsOfInterest)

class PacketTunnelProvider: NEPacketTunnelProvider {
    var pa:SwiftPacketAdapter!
    var nextHandler:((Error?) -> Void)?
    var account:UnsafeMutablePointer<ACCOUNT>?
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Parse Config
//        var configProto = protocolConfiguration as! SoftEtherVPNProtocol
//
//        _ = configProto.config.name
        // Init SoftEther
        OSInit()
        InitCryptLibrary()
        InitNetwork()
        InitSwiftNetwork(self)
        InitOsInfo()
        InitThreading()
        InitStringLibrary()
        
        // Configure tunnel with options
        let auth = CLIENT_AUTH.setup("asd","asdpas")
        let opt = CLIENT_OPTION.setup("192.168.0.2", 443,hub:"DEFAULT")
        account = ACCOUNT.setup(opt, auth)
       
        // Create SoftEther Client
        let cli = CiNewClient()!
        InitSwiftConnection(cli.pointee.Cedar)
        
        // Handle Client notifications
        let cancel = NewCancel()!
        let handle = FileHandle.init(fileDescriptor: cancel.pointee.pipe_read)
        handle.readabilityHandler = clientChanged
        Add(cli.pointee.NotifyCancelList, cancel)
        
        pa = SwiftPacketAdapter(self)
        
        account!.pointee.ClientSession = NewClientSessionEx(cli.pointee.Cedar, opt, auth, GenPacketAdapter(pa), account, nil)
        
        nextHandler = completionHandler
    }
    
    func currErr() -> Error{
        return NSError(domain: "tech.nsyd.se.SENE", code: -Int(s?.Err ?? 1), userInfo: nil)
    }
    
    func clientChanged(_ fd:FileHandle) {
        _ = fd.readDataToEndOfFile()
        if self.s?.ClientStatus ?? 0 == CLIENT_STATUS_IDLE{
            self.cancelTunnelWithError(self.currErr())
        }
    }
    
    override func setTunnelNetworkSettings(_ tunnelNetworkSettings: NETunnelNetworkSettings?, completionHandler: ((Error?) -> Void)? = nil) {
        super.setTunnelNetworkSettings(tunnelNetworkSettings, completionHandler: completionHandler)
        nextHandler?(nil) // TODO: Change ipc to use clientChanged if possible
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        StopSession(account?.pointee.ClientSession)
        completionHandler() // TODO: Change stopTunnel to use clientChanged
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    var s:SESSION?{
        get {
            return account?.pointee.ClientSession?.pointee
        }
        set {
            if let newValue = newValue {
                account?.pointee.ClientSession?.pointee = newValue
            }else{
                account?.pointee.ClientSession = nil
            }
        }
    }
    
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}


public typealias ErrFunc = ((_ error: Error?) -> Void)

//class SClientThread: NamedThread {
//    var stratHandler : ErrFunc
//    public var endHandler : (()->Void)?
//    let tun:PacketTunnelProvider
//
//    init(_ tun:PacketTunnelProvider, _ stratHandler:@escaping ErrFunc) {
//        self.tun = tun
//        self.stratHandler = stratHandler
//        super.init(ClientThread, tun.session, "ClientThread")
//        super.exitFunc = onTerminate
//    }
//
//    func currErr() -> Error{
//        return NSError(domain: "tech.nsyd.se.ne.ClientThread", code: -Int(tun.s.Err), userInfo: nil)
//    }
//
//    func onTerminate() {
//        if let end = endHandler {
//            end()
//        }else{
//            let e = currErr()
//            NSLog("Exit Error: %@", e.localizedDescription)
//            tun.cancelTunnelWithError(e)
//        }
//    }
//
//    func Connected() {
//        stratHandler(nil)
//    }
//
//    //    @_silgen_name("SessionConnected")
//    static func SConnected(_ t: UnsafeMutablePointer<THREAD>!){
//        guard let thread:Thread = GetOpaque(t) else{
//            return
//        }
//        guard let client = thread as? SClientThread else {
//            return
//        }
//        client.Connected()
//    }
//}
