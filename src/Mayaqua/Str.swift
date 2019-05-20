//
//  Str.swift
//  SoftEtherNE
//
//  Created by Gentoli on 2018/7/30.
//

import Foundation

//@_silgen_name("StrCpy")
//public func StrCpy(_ dst: UnsafeMutablePointer<Int8>!, _ size: UINT, _ src: UnsafeMutablePointer<Int8>!) -> UINT{
//    var sizem = size
//    if dst == src{
//        return StrLen(src)
//    }
//    if dst == nil || src == nil{
//        if src == nil && dst != nil{
//            dst.assign(repeating: 0, count: 1);
//        }
//        return 0
//    }
//    if sizem == 1{
//        dst.assign(repeating: 0, count: 1);
//        return 0
//    }
//    if (sizem == 0)
//    {
//        // Ignore the length
//        sizem = 0x7fffffff;
//    }
//
//    // Check the length
//    var len = StrLen(src);
//    if (len <= (sizem - 1))
//    {
//        UnsafeMutableRawPointer(dst)?.copyMemory(from: src, byteCount: Int(len+1))
//    }
//    else
//    {
//        len = sizem - 1;
//        UnsafeMutableRawPointer(dst)?.copyMemory(from: src, byteCount: Int(len))
//        dst.advanced(by: Int(len)).assign(repeating: 0, count: 1)
//    }
//
//    return 0
//}
//
//@_silgen_name("StrLen")
//public func StrLen(_ str: UnsafeMutablePointer<Int8>!) -> UINT{
//    if (str == nil)
//    {
//        return 0
//    }
//    return UINT(strlen(str))
//}
//
//@_silgen_name("StrCmpi")
//public func StrCmpi(_ str1: UnsafeMutablePointer<Int8>!, _ str2: UnsafeMutablePointer<Int8>!) -> Int32
//{
//    // Validate arguments
//    if (str1 == nil && str2 == nil)
//    {
//        return 0;
//    }
//    if (str1 == nil)
//    {
//        return 1;
//    }
//    if (str2 == nil)
//    {
//        return -1;
//    }
//
//    // String comparison
//    var i = 0;
//    while (true)
//    {
//        var c1:Int8
//        var c2:Int8
//        c1 = ToUpper(str1[i]);
//        c2 = ToUpper(str2[i]);
//        if (c1 > c2)
//        {
//            return 1;
//        }
//        else if (c1 < c2)
//        {
//            return -1;
//        }
//        if (str1[i] == 0 || str2[i] == 0)
//        {
//            return 0;
//        }
//        i+=1;
//    }
//}
//
//@_silgen_name("StrCmp")
//public func StrCmp(_ str1: UnsafeMutablePointer<Int8>!, _ str2: UnsafeMutablePointer<Int8>!) -> Int32{
//    if (str1 == nil && str2 == nil)
//    {
//        return 0;
//    }
//    if (str1 == nil)
//    {
//        return 1;
//    }
//    if (str2 == nil)
//    {
//        return -1;
//    }
//
//    return strcmp(str1, str2)
//}
//
//@_silgen_name("CopyStr")
//public func CopyStr(_ str: UnsafeMutablePointer<Int8>!) -> UnsafeMutablePointer<Int8>!{
//    let l = StrLen(str)
//    let ptr = UnsafeMutableRawPointer.allocate(byteCount: Int(l), alignment: 0)
//    ptr.copyMemory(from: str, byteCount: Int(l+1))
//    return ptr.assumingMemoryBound(to: Int8.self)
//}
//
//@_silgen_name("ToLower")
//public func ToLower(_ c: Int8) -> Int8{
//    var c1 = c
//    if ("A".toInt8 <= c && c <= "Z".toInt8)
//    {
//        c1 += "z".toInt8 - "Z".toInt8;
//    }
//    return c1
//}
//
//@_silgen_name("ToUpper")
//public func ToUpper(_ c: Int8) -> Int8{
//    var c1 = c
//    if ("a".toInt8 <= c && c <= "z".toInt8)
//    {
//        c1 += "Z".toInt8 - "z".toInt8;
//    }
//    return c1
//}
//
//extension String{
//    var toInt8:Int8 {
//        return Int8(self)!
//    }
//}
