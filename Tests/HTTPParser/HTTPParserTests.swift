//
//  HTTPParserTests.swift
//  HTTPParserTests
//
//  Created by Helge Hess on 25/04/16.
//  Copyright © 2016 Always Right Institute. All rights reserved.
//

import XCTest
@testable import HTTPParser

class HTTPParserTests: XCTestCase {
  
  let simpleGetRequest =
    "GET /index.html HTTP/1.1\r\n" +
    "Content-length: 0\r\n" +
    "Content-type: text/plain\r\n" +
    "\r\n";

  let debugLog = false
  
  func testSimpleGetRequest() {
    let debugLog = self.debugLog // capture
    
    let parser = HTTPParser(type: .Request)
    XCTAssertNotNil(parser)
    
    // NOTE: The approach to collect headers shown here does NOT WORK for
    //       sources pushing in chunks of data
    var lastHeaderField : String? = nil
    var headers = Dictionary<String, String>()
    
    parser.onMessageBegin { p in
      if debugLog { print("*** CB: message begin") }
      return 0
    }
    parser.onMessageComplete { p in
      if debugLog { print("*** CB: message DONE") }
      return 0
    }
    parser.onHeadersComplete { p in
      if debugLog { print("*** CB: headers done: method=\(p.method)") }
      XCTAssertNotNil(p.method)
      XCTAssertEqual(p.method, HTTPMethod.GET)
      XCTAssertEqual(p.http_major!, 1)
      XCTAssertEqual(p.http_minor!, 1)
      return 0
    }
    parser.onHeaderField { p, ptr, len in
      let s = String.fromCString(ptr, length: len)
      if debugLog { print("*** CB: header field: \(s)") }
      lastHeaderField = s
      return 0
    }
    parser.onHeaderValue { p, ptr, len in
      let s = String.fromCString(ptr, length: len)
      if debugLog { print("*** CB: header value: \(s)") }
      XCTAssert(s != nil)
      XCTAssert(lastHeaderField != nil)
      headers[lastHeaderField!] = s!
      return 0
    }
    parser.onBody { p, ptr, len in
      if debugLog { print("*** CB: body") }
      XCTAssertEqual(0,len) // no body in request
      return 0
    }
    parser.onStatus { p, ptr, len in
      let s = String.fromCString(ptr, length: len)
      if debugLog { print("*** CB: status \(s)") }
      XCTAssert(false) // should not be called on request ...
      return 0
    }
    parser.onURL { p, ptr, len in
      let s = String.fromCString(ptr, length: len)
      if debugLog { print("*** CB: url: \(s)") }
      XCTAssertEqual(s!, "/index.html")
      return 0
    }
    
    simpleGetRequest.withCString { cstr in
      let len = size_t(strlen(cstr))
      let nb  = parser.execute(cstr, len)
      
      XCTAssertEqual(len, nb)
    }
    
    // send EOF
    let nb  = parser.execute(nil, 0)
    XCTAssertEqual(nb, 0)
    
    
    // finish up
    if debugLog { print("HEADERS: \(headers)") }
    XCTAssert(headers.count == 2)
    XCTAssertEqual(headers["Content-type"],   "text/plain")
    XCTAssertEqual(headers["Content-length"], "0")
  }
  
}
