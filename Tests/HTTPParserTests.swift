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

  func testSimpleGetRequest() {
    let parser = HTTPParser(type: .HTTP_REQUEST)
    XCTAssertNotNil(parser)
    
    parser.onMessageBegin = { p in
      print("CB: message begin")
      return 0
    }
    parser.onHeaderField = { p, ptr, len in
      print("CB: header field")
      return 0
    }
    parser.onBody = { p, ptr, len in
      print("CB: body")
      return 0
    }
    parser.onStatus = { p, ptr, len in
      print("CB: status")
      return 0
    }
    parser.onURL = { p, ptr, len in
      print("CB: url")
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
  }
  
}
