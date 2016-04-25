//
//  HTTPMethod.swift
//  HTTPParser
//
//  Created by Helge Heß on 6/19/14.
//  Copyright © 2014 Always Right Institute. All rights reserved.
//
/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

public enum HTTPMethod : Int {
  case DELETE = 0
  
  case GET
  case HEAD
  case POST
  case PUT
  /* pathological */
  case CONNECT
  case OPTIONS
  case TRACE
  /* WebDAV */
  case COPY
  case LOCK
  case MKCOL
  case MOVE
  case PROPFIND
  case PROPPATCH
  case SEARCH
  case UNLOCK
  case BIND
  case REBIND
  case UNBIND
  case ACL
  /* subversion */
  case REPORT
  case MKACTIVITY
  case CHECKOUT
  case MERGE
  /* upnp */
  case MSEARCH
  case NOTIFY
  case SUBSCRIBE
  case UNSUBSCRIBE
  /* RFC-5789 */
  case PATCH
  case PURGE
  /* CalDAV */
  case MKCALENDAR
  /* RFC-2068, section 19.6.1.2 */ 
  case LINK
  case UNLINK
  

  public init?(string: String) {
    switch string {
      case "GET":         self = .GET
      case "HEAD":        self = .HEAD
      case "PUT":         self = .PUT
      case "DELETE":      self = .DELETE
      case "POST":        self = .POST
      case "OPTIONS":     self = .OPTIONS
      
      case "PROPFIND":    self = .PROPFIND
      case "PROPPATCH":   self = .PROPPATCH
      case "MKCOL":       self = .MKCOL
      
      case "REPORT":      self = .REPORT
      
      case "MKCALENDAR":  self = .MKCALENDAR
      
      case "CONNECT":     self = .CONNECT
      case "TRACE":       self = .TRACE
      
      case "COPY":        self = .COPY
      case "MOVE":        self = .MOVE
      case "LOCK":        self = .LOCK
      case "UNLOCK":      self = .UNLOCK
      
      case "SEARCH":      self = .SEARCH
      
      case "MKACTIVITY":  self = .MKACTIVITY
      case "CHECKOUT":    self = .CHECKOUT
      case "MERGE":       self = .MERGE
      
      case "M-SEARCH":    self = .MSEARCH
      case "NOTIFY":      self = .NOTIFY
      case "SUBSCRIBE":   self = .SUBSCRIBE
      case "UNSUBSCRIBE": self = .UNSUBSCRIBE
      
      case "PATCH":       self = .PATCH
      case "PURGE":       self = .PURGE
      
      case "ACL":         self = .ACL
      case "BIND":        self = .BIND
      case "UNBIND":      self = .UNBIND
      case "REBIND":      self = .REBIND
      
      case "LINK":        self = .LINK
      case "UNLINK":      self = .UNLINK
      
      default: return nil
    }
  }
  
}

public extension HTTPMethod {

  public var method: String {
    switch self {
      case .GET:        return "GET"
      case .HEAD:       return "HEAD"
      case .PUT:        return "PUT"
      case .DELETE:     return "DELETE"
      case .POST:       return "POST"
      case .OPTIONS:    return "OPTIONS"
        
      case .PROPFIND:   return "PROPFIND"
      case .PROPPATCH:  return "PROPPATCH"
      case .MKCOL:      return "MKCOL"
        
      case .REPORT:     return "REPORT"
        
      case .MKCALENDAR: return "MKCALENDAR"

      case .CONNECT:    return "CONNECT"
      case .TRACE:      return "TRACE"
      
      case .COPY:       return "COPY"
      case .MOVE:       return "MOVE"
      case .LOCK:       return "LOCK"
      case .UNLOCK:     return "UNLOCK"
      
      case .SEARCH:     return "SEARCH"
      
      case .MKACTIVITY: return "MKACTIVITY"
      case .CHECKOUT:   return "CHECKOUT"
      case .MERGE:      return "MERGE"
      
      case .MSEARCH:    return "M-SEARCH"
      case .NOTIFY:     return "NOTIFY"
      case .SUBSCRIBE:  return "SUBSCRIBE"
      case .UNSUBSCRIBE:return "UNSUBSCRIBE"

      case .PATCH:      return "PATCH"
      case .PURGE:      return "PURGE"
      
      case .ACL:        return "ACL"
      case .BIND:       return "BIND"
      case .UNBIND:     return "UNBIND"
      case .REBIND:     return "REBIND"
      
      case .LINK:       return "LINK"
      case .UNLINK:     return "UNLINK"
    }
  }
  
  public var isSafe: Bool? { // can't say for extension methods
    switch self {
      case .GET, .HEAD, .OPTIONS:
        return true
      case .PROPFIND, .REPORT:
        return true
      default:
        return false
    }
  }
  
  public var isIdempotent: Bool? { // can't say for extension methods
    switch self {
      case .GET, .HEAD, .PUT, .DELETE, .OPTIONS:
        return true
      case .PROPFIND, .REPORT, .PROPPATCH:
        return true
      case .MKCOL, .MKCALENDAR:
        return true
      default:
        return false
    }
  }
}

extension HTTPMethod : CustomStringConvertible {
  
  public var description: String {
    return method
  }
}


// original compat

public func http_method_str(method: HTTPMethod) -> String {
  return method.description
}
