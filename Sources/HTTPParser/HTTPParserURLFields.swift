//
//  HTTPParserURLFields.swift
//  HTTPParser
//
//  Created by Helge Heß on 4/25/16.
//  Copyright © 2016 Always Right Institute. All rights reserved.
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

// enum http_parser_url_fields
// This is not a bitset in http_parser.h
public struct HTTPParserURLFields : OptionSetType {

  public let rawValue : Int
  
  public init(rawValue: Int = 0) {
    self.rawValue = rawValue
  }
  
  static let SCHEMA   = HTTPParserURLFields(rawValue: 1 << 0)
  static let HOST     = HTTPParserURLFields(rawValue: 1 << 1)
  static let PORT     = HTTPParserURLFields(rawValue: 1 << 2)
  static let PATH     = HTTPParserURLFields(rawValue: 1 << 3)
  static let QUERY    = HTTPParserURLFields(rawValue: 1 << 4)
  static let FRAGMENT = HTTPParserURLFields(rawValue: 1 << 5)
  static let USERINFO = HTTPParserURLFields(rawValue: 1 << 6)
}
