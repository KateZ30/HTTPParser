//
//  CString.swift
//  HTTPParser
//
//  Created by Helge Heß on 4/26/16.
//  Copyright © 2016 Always Right Institute. All rights reserved.
//
#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

// Those are mostly dirty hacks to get what I need :-)
// I would be very interested in better way to do those things, W/O using
// Foundation.

extension String {
  
  func makeCString() -> UnsafePointer<CChar> {
    var ptr : UnsafeMutablePointer<CChar> = nil
    self.withCString { cstr in
      let len = strlen(cstr)
      ptr = UnsafeMutablePointer<CChar>.alloc(Int(len) + 1)
      strcpy(ptr, cstr)
    }
    return UnsafePointer<CChar>(ptr)
  }
  
  static func fromCString(cs: UnsafePointer<CChar>, length: Int!) -> String? {
    guard length != .None else { // no length given, use \0 standard variant
      return String.fromCString(cs)
    }
    
    let buflen = length + 1
    let buf    = UnsafeMutablePointer<CChar>.alloc(buflen)
    memcpy(buf, cs, length)
    buf[length] = 0 // zero terminate
    let s = String.fromCString(buf)
    buf.dealloc(buflen)
    return s
  }

}
