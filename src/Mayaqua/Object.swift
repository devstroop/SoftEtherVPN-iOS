//
//  Object.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/30.
//

import Foundation


class Counter{ // Author: nestserau@github
    private let lock = DispatchSemaphore(value: 1)
    private var _value: UINT
    
    public init(value initialValue: UINT = 0) {
        _value = initialValue
    }
    
    public var value: UINT {
        get {
            lock.wait()
            defer { lock.signal() }
            return _value
        }
        set {
            lock.wait()
            defer { lock.signal() }
            _value = newValue
        }
    }
    
    public func decrementAndGet() -> UINT {
        lock.wait()
        defer { lock.signal() }
        _value -= 1
        return _value
    }
    
    public func incrementAndGet() -> UINT {
        lock.wait()
        defer { lock.signal() }
        _value += 1
        return _value
    }
    
//    @_silgen_name("NewCounter")
    public static func CNewCounter() -> UnsafeMutablePointer<COUNTER>!{
        return ToOpaque(Counter())
    }

//    @_silgen_name("DeleteCounter")
    public static func CDeleteCounter(_ c: UnsafeMutablePointer<COUNTER>!){
        ReleaseOpaque(c)
    }

//    @_silgen_name("Count")
    public static func CCount(_ c: UnsafeMutablePointer<COUNTER>!) -> UINT{
        guard let obj:Counter = GetOpaque(c) else{
            return 0
        }
        return obj.value
    }

//    @_silgen_name("Inc")
    public static func CInc(_ c: UnsafeMutablePointer<COUNTER>!) -> UINT{
        guard let obj:Counter = GetOpaque(c) else{
            return 0
        }
        return obj.incrementAndGet()
    }

//    @_silgen_name("Dec")
    public static func CDec(_ c: UnsafeMutablePointer<COUNTER>!) -> UINT{
        guard let obj:Counter = GetOpaque(c) else{
            return 0
        }
        return obj.decrementAndGet()
    }
}

public class Event : NSCondition{
    private let lock = DispatchSemaphore(value: 1)
    private var _value: UInt32 = 0
    
    public var value: UInt32 {
        get {
            lock.wait()
            defer { lock.signal() }
            return _value
        }
        set {
            lock.wait()
            defer { lock.signal() }
            _value = newValue
        }
    }
    
//    @_silgen_name("NewEvent")
    public static func CNewEvent() -> UnsafeMutablePointer<EVENT>!{
        return ToOpaque(Event())
    }


//    @_silgen_name("ReleaseEvent")
    public static func CReleaseEvent(_ e: UnsafeMutablePointer<EVENT>!){
        ReleaseOpaque(e)
    }

//    @_silgen_name("Set")
    public static func CSet(_ e: UnsafeMutablePointer<EVENT>!){
        guard let obj:Event = GetOpaque(e) else{
            return
        }
        obj.value = 1
        obj.signal()
        
    }

    // return 0 on timeout
//    @_silgen_name("Wait")
    public static func CWait(_ e: UnsafeMutablePointer<EVENT>!, _ timeout: UINT) -> Bool{
        guard let obj:Event = GetOpaque(e) else{
            return false
        }
        defer {
            obj.value = 0
        }
        if timeout == INFINITE{
            while obj.value == 0 {
                obj.wait()
            }
        }else{
            let until = timeoutDate(timeout)
            while obj.value == 0 {
                return obj.wait(until: until)
            }
        }
        return true
    }

//    @_silgen_name("WaitEx")
    public static func CWaitEx(_ e: UnsafeMutablePointer<EVENT>!, _ timeout: UINT, _ cancel: UnsafeMutablePointer<Bool>!) -> Bool{
        return false
    }
}


public class Lock : NSRecursiveLock{
    // value = 0 => ready
//    @_silgen_name("NewLock")
    public static func CNewLock() -> UnsafeMutablePointer<LOCK>!{
        return ToOpaque(Lock())
    }
    
//    @_silgen_name("DeleteLock")
    public static func CDeleteLock(_ lock: UnsafeMutablePointer<LOCK>!){
        ReleaseOpaque(lock)
    }
    
//    @_silgen_name("UnlockInner")
    public static func CUnlockInner(_ lock: UnsafeMutablePointer<LOCK>!){
        guard let obj:Lock = GetOpaque(lock) else{
            return
        }
        obj.unlock()
    }
    
//    @_silgen_name("LockInner")
    public static func CLockInner(_ lock: UnsafeMutablePointer<LOCK>!) -> Bool{
        guard let obj:Lock = GetOpaque(lock) else{
            return false
        }
        return obj.try()
    }
    
//    @_silgen_name("NewLockMain")
    public static func CNewLockMain() -> UnsafeMutablePointer<LOCK>!{
        return CNewLock()
    }
}


