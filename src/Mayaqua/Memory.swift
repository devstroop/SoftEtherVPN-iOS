//
//  Memory.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/30.
//

import Foundation
import os.signpost

public func salloc<T>(_ type: T.Type)->UnsafeMutablePointer<T>{
    let ptr = ZeroMalloc(UINT(MemoryLayout<T>.size))!
//    NSLog("alloc \(T.self) @ \(ptr)")
    return ptr.assumingMemoryBound(to: T.self)
}

public func salloc<T>()->UnsafeMutablePointer<T>{
    return salloc(T.self)
}

//@_silgen_name("ZeroMalloc")
//public func CZeroMalloc(_ size: UINT) -> UnsafeMutableRawPointer!{
//    return SZeroMalloc(Int(size))
//}

//@_silgen_name("Zero")
public func CZero(_ addr: UnsafeMutableRawPointer!, _ size: UINT){
    addr.initializeMemory(as: UInt8.self, repeating: 0, count: Int(size))
}
let memlock = NSCondition()
var memlist = [UnsafeMutableRawPointer:String]()

//@_silgen_name("ZeroMallocEx")
func SZeroMallocEx(_ size: UINT, _ zero_clear_when_free: Bool) -> UnsafeMutableRawPointer!{
    let ptr = CMalloc(size)
    CZero(ptr, size)
    return ptr
}

//@_silgen_name("MallocEx")
func SMallocEx(_ size: UINT, _ zero_clear_when_free: Bool) -> UnsafeMutableRawPointer!{
    return CMalloc(size)
}

//@_silgen_name("InternalMalloc")
//@_silgen_name("Malloc")
public func CMalloc(_ size: UINT) -> UnsafeMutableRawPointer!{
    let ptr = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 0)
//    let ptr = malloc(Int(size))!
    if doLog {
        var log = true
        var str = ""
        var i = 0
        memlock.lock()
        for symbol in Thread.callStackSymbols {
            if symbol.contains("Malloc"){
                continue
            }
            if symbol.contains("ARP"){
                log = false
                break
            }
            let index = symbol.index(str.startIndex, offsetBy: 59)
            let a = symbol.substring(from: index)
            let end = a.firstIndex(of: " ")
            
            str.append(a.substring(to: end!))
            str.append(" <- ")
            i+=1
            if i>7{
                break
            }
        }
//        NSLog("Malloc \(ptr):\n\(str)")
        if log{
            memlist[ptr]=str
        }
        memlock.unlock()
        
    }
    let diff = ptr.distance(to: UnsafeMutableRawPointer(bitPattern: 0x0000000200000000)!)
    if diff <= 0{
        return nil
    }
    return ptr
}

func getMEM(){
    for m in memlist{
        NSLog("Pointer: \(m)")
    }
}

//public func SMalloc(_ size: Int) -> UnsafeMutableRawPointer{
//    return
//}
//
//func SZeroMalloc(_ size: Int) -> UnsafeMutableRawPointer{
//    let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 0)
//    ptr.initializeMemory(as: UInt8.self, repeating: 0, count: size)
//    return ptr
//}

//@_silgen_name("Copy")
public func SCopy(_ dst: UnsafeMutableRawPointer!, _ src: UnsafeMutableRawPointer!, _ size: UINT){
    dst.copyMemory(from: src, byteCount: Int(size))
}
var freeOnly = [UnsafeMutableRawPointer]()

var doLog = false
// p doLog = true
//@_silgen_name("InternalFree")
//@_silgen_name("Free")
public func CFree(_ addr: UnsafeMutableRawPointer?){
    guard let addr = addr else {
        return
    }
    if doLog{
        let diff = addr.distance(to: UnsafeMutableRawPointer(bitPattern: 0x0000000200000000)!)
        if diff <= 0{
            return
        }
        memlock.lock()
        if memlist.removeValue(forKey: addr) == nil {
            freeOnly.append(addr)
        }
        memlock.unlock()
    }
    
    // Deallocate is some how not thread safe
//    freeQue.sync {
    addr.deallocate()
//    }
}
//let freeLock = NSCondition()
let freeQue = DispatchQueue.init(label: "FreeQueue")
//@_silgen_name("InternalReAlloc")
//@_silgen_name("ReAlloc")
func InternalReAlloc(_ addr: UnsafeMutableRawPointer!, _ size: UINT) -> UnsafeMutableRawPointer!{
    let ptr = realloc(addr,Int(size))
    if ptr!.distance(to: UnsafeMutableRawPointer(bitPattern: 0x0000000200000000)!) <= 0{
        return nil
    }
    return ptr
}
