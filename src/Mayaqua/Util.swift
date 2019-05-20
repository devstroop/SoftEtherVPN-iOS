//
//  Util.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/27.
//

import Foundation
import os.signpost

public extension String{
    func setPtr( _ ptr:UnsafeMutableRawPointer){
        withCString { (str) in
            ptr.copyMemory(from: str, byteCount: self.count+1)
        }
//        if var data = self.data(using: String.Encoding.utf8){
//            data.append(0)
//
//            data.withUnsafeBytes { (byt) in
//                ptr.copyMemory(from: byt, byteCount: self.count+1)
//            }
//        }
    }
    
    func newPtr()->UnsafeMutableRawPointer{
        let rtn = Malloc(UINT((self.count+2)*MemoryLayout<UInt8>.size))!
        setPtr(rtn)
        return rtn
    }
}


@_silgen_name("s_setsockopt")
func s_setsockopt(_: Int32, _: Int32, _: Int32, _: UnsafeRawPointer!, _: socklen_t) -> Int32{
    return 0
}

@_silgen_name("s_system")
public func s_system(_ command: UnsafePointer<Int8>!) -> Int32{
    return 0
}
@_silgen_name("s_read")
public func s_read(_: Int32, _: UnsafeMutableRawPointer!, _: Int) -> Int{
    return 0
}

@_silgen_name("s_fputs")
public func SNSLog(_ pipe: UnsafeMutablePointer<UInt8>, _ msg: UnsafeMutablePointer<UInt8>){
    let str = String(cString: msg)
    let pi = String(cString: pipe)
    NSLog("%@: %@",pi,str)
}

var os_info:UnsafeMutablePointer<OS_INFO>?

//@_silgen_name("GetOsInfo")
public func SGetOsInfo() -> UnsafeMutablePointer<OS_INFO>!{
    if let os = os_info{
        return os
    }
    var info = OS_INFO()
    info.OsProductName = "iOS".newPtr().assumingMemoryBound(to: Int8.self)
//    info.OsVersion = String(UIDevice.current.systemVersion).newPtr().assumingMemoryBound(to: Int8.self)
    os_info = salloc(OS_INFO.self)
    os_info?.pointee = info
    return os_info
}

//@_silgen_name("OSGetProductId")
public func SOSGetProductId() -> UnsafeMutablePointer<Int8>!{
    return "--".newPtr().assumingMemoryBound(to: Int8.self)
}

//@_silgen_name("UINT64ToSystem")
public func SUINT64ToSystem(_ st: UnsafeMutablePointer<SYSTEMTIME>!, _ sec64: UINT64){
    let date = Date.init(timeIntervalSince1970: TimeInterval(sec64/1000))
    var time = SYSTEMTIME()
    let calendar = Calendar.current
    time.wDay = WORD(calendar.component(.day, from: date))
    time.wHour = WORD(calendar.component(.hour, from: date))
    time.wYear = WORD(calendar.component(.year, from: date))
    time.wMonth = WORD(calendar.component(.month, from: date))
    time.wDayOfWeek = WORD(calendar.component(.weekday, from: date))
    time.wMilliseconds = WORD(calendar.component(.nanosecond, from: date)*1000)
    time.wMinute = WORD(calendar.component(.minute, from: date))
    time.wSecond = WORD(calendar.component(.second, from: date))
    st.pointee = time
    
}

//@_silgen_name("SystemTime64")
public func CSystemTime64() -> UINT64{
    return UINT64(Date().timeIntervalSince1970*1000)
}



@_silgen_name("Tick64")
public func CTick64() -> UINT64{
    struct TickStart{
        // first evluated when used, it on the right of - in return, it will be smaller than now()
        static var value = DispatchTime.now().uptimeNanoseconds/1000000 - 50001
    }
    return DispatchTime.now().uptimeNanoseconds/1000000 - TickStart.value
}

@_silgen_name("TickHighres64")
public func CTickHighres64() -> UINT64{
    return Tick64()
}
//
//@_silgen_name("GetGlobalServerFlag")
//func GetGlobalServerFlag(_ index: UINT) -> UINT{
//    if index == GSF_DISABLE_SESSION_RECONNECT{
//        return 0
//    }
//    return 1
//}



open class NamedThread: Thread {
    let mainFunc:THREAD_PROC
    public var exitFunc: (()->())?
    let param:UnsafeMutableRawPointer?
    var ptr:UnsafeMutablePointer<THREAD>!
    var t:THREAD {
        get{
            return ptr.pointee
        }
        set{
            ptr.pointee = newValue
        }
    }
    let lock = NSCondition()
    var hasInit = false
    
    
    public init(_ thread_proc: @escaping THREAD_PROC, _ param: UnsafeMutableRawPointer!,_ name: String,_ exit: (()->())? = nil) {
        mainFunc=thread_proc
        self.param=param
        exitFunc=exit
        super.init()
      

        
        super.name=name
        
        if super.name == "ClientThread"{
            Thread.setThreadPriority(1)
        }
        
        ptr = salloc()
        t.ref = NewRef()
        t.AppData1 = UnsafeMutableRawPointer(ToOpaque(self))
        
        super.start()
    }
    
    override open func main() {
        NSLog("Init %@...", name ?? "unnamed")
        mainFunc(ptr!,param)
        NSLog("Exiting %@...", name ?? "unnamed")
        if let exit = exitFunc{
            exit()
        }
        ReleaseOpaque(t.AppData1)
    }
    
//    @_silgen_name("NewThreadNamed")
    public static func SNewThreadNamed(_ thread_proc: @escaping @convention(c) (UnsafeMutablePointer<THREAD>?, UnsafeMutableRawPointer?) -> Void, _ param:  UnsafeMutableRawPointer, _ name: UnsafeMutablePointer<Int8>!) -> UnsafeMutablePointer<THREAD>!{
        return NamedThread(thread_proc,param,String(cString: name)).ptr!
    }
    
    fileprivate static func GetThread(_ t: UnsafeMutablePointer<THREAD>?) -> NamedThread? {
        return GetOpaque(t!.pointee.AppData1)
    }
    
//    @_silgen_name("WaitThreadInit")
    public static func SWaitThreadInit(_ t: UnsafeMutablePointer<THREAD>!){
        guard let nt:NamedThread = GetThread(t) else{
            return
        }
        while(!nt.hasInit){
            nt.lock.wait()
        }
    }
    
//    @_silgen_name("ReleaseThread")
    public static func SReleaseThread(_ t: UnsafeMutablePointer<THREAD>!){
        //ReleaseOpaque(t)
    }
    
//    @_silgen_name("NoticeThreadInit")
    public static func SNoticeThreadInit(_ t: UnsafeMutablePointer<THREAD>!){
        guard let nt:NamedThread = GetThread(t) else{
            return
        }
        nt.hasInit=true
        nt.lock.broadcast()
    }
}

public func GetOpaque<T:AnyObject>(_ ptr: UnsafeRawPointer?)->T?{
    guard let p = ptr else {
        return nil
    }
    let opq = Unmanaged<T>.fromOpaque(p)
    return opq.takeUnretainedValue()
}

public func ToOpaque<T:AnyObject>(_ obj: T)->UnsafeMutableRawPointer{
    let i = Unmanaged<T>.passRetained(obj)
    i.retain()
    return i.toOpaque()
}

public func ToOpaque<T:AnyObject,S>(_ obj: T)->UnsafeMutablePointer<S>{
    return ToOpaque(obj).assumingMemoryBound(to: S.self)
}

public func ReleaseOpaque(_ ptr: UnsafeRawPointer?){
    guard let p = ptr else {
        return
    }
    Unmanaged<AnyObject>.fromOpaque(p).release()
}

public func timeoutDate(_ time: UINT) -> Date {
    return timeoutDate(Double(time))
}

public func timeoutDate(_ time: Int) -> Date {
    return timeoutDate(Double(time))
}

public func timeoutDate(_ time: Double) -> Date {
    return Date().addingTimeInterval(TimeInterval(time))
}

public func DispatchTimeout(_ miliseconds: UInt32)->DispatchTime{
    return DispatchTimeout(UInt64(miliseconds)*1000000)
}
public func DispatchTimeout(_ nanoseconds: UInt64)->DispatchTime{
    return DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + nanoseconds)
}

// true on success
@discardableResult
public func SemaphoreWait(_ ds: DispatchSemaphore, _ miliseconds: UInt32) -> DispatchTimeoutResult{
    return ds.wait(timeout: DispatchTimeout(miliseconds))
}

@discardableResult
public func SemaphoreWait(_ ds: DispatchSemaphore, until miliseconds: UInt32)->DispatchTimeoutResult{
    return ds.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64(miliseconds)*1000000))
}
// .disabled //
let poi:OSLog = .disabled //OSLog.init(subsystem: "event", category: .pointsOfInterest)

@_silgen_name("signEvent")
public func SsignEvent(_ name: UnsafeMutablePointer<Int8>!, _ size: uint){
//        autoreleasepool {
//            let a = String.init(cString: UnsafePointer<CChar>(name!))
//            os_signpost(.event, log: poi, name: "CLog", "%{public}@: %d", a,size)
//        }
}
@_silgen_name("FileOpen")
public func SFileOpen(_ name: UnsafeMutablePointer<Int8>!, _ write_mode: Bool) -> UnsafeMutablePointer<IO>!{
    return nil
}


class LinkedList<T> {
    var next:LinkedList<T>?
    var value:T
    init(_ value: T) {
        self.value = value
    }
    static func create(_ parent:LinkedList<T>?,_ value:T) -> LinkedList<T> {
        let rtn = LinkedList<T>(value)
        if let parent = parent{
            parent.next = rtn
        }
        return rtn
    }
    static func read(_ from:inout LinkedList<T>?) -> T? {
        guard let head = from else{
            return nil
        }
        from = head.next
        return head.value
    }
}
public class LinkedListHead<T> {
    var head:LinkedList<T>?
    var tail:LinkedList<T>?
    public let append = put
    public let removeFirst = pop
    public var count = 0
    
    public init(){}
    
    public func put(_ t:T) {
        tail = LinkedList<T>.create(tail,t)
        if head == nil {
            head = tail
        }
        count+=1
    }
    
    public func isEmpty() -> Bool {
        return head == nil
    }
    
    public func peak() -> T? {
        return head?.value
    }
    
    public func replaceHead(_ value:T) {
        head!.value = value
    }
    
    public func pop() -> T? {
        count-=1
        return LinkedList<T>.read(&head)
    }
}
