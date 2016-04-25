//
//  HTTPMethod.swift
//  HTTPParser
//
//  Created by Helge Heß on 6/19/14.
//  Copyright © 2014 Always Right Institute. All rights reserved.
//

public enum HTTPMethod : Int {
  // Either inherit from Int (and have raw values) OR have cases with arguments
  
  case GET, HEAD, PUT, DELETE, POST, OPTIONS
  
  case PROPFIND, PROPPATCH, MKCOL
  
  case REPORT
  
  case MKCALENDAR
  
  case BATCH // ;-)
  
  case CONNECT, TRACE
  case COPY, MOVE
  case LOCK, UNLOCK
  case SEARCH
  
  case MKACTIVITY, CHECKOUT, MERGE
  case MSEARCH, NOTIFY, SUBSCRIBE, UNSUBSCRIBE
  
  case PATCH, PURGE
  
  case ACL, BIND, UNBIND, REBIND
  case LINK, UNLINK
  

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
      
      case "BATCH":       self = .BATCH
      
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
        
      case .BATCH:      return "BATCH"

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
      case .BATCH:
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
      case .BATCH:
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
