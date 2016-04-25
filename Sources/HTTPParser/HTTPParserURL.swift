//
//  HTTPParserURL.swift
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

/* Result structure for http_parser_parse_url().
 *
 * Callers should index into field_data[] with UF_* values iff field_set
 * has the relevant (1 << UF_*) bit set. As a courtesy to clients (and
 * because we probably have padding left over), we convert any port to
 * a uint16_t.
 */

public struct HTTPParserURL {
  
  var field_set : HTTPParserURLFields
  var port      : UInt16 // Converted UF_PORT string
  
  /* Offset into buffer in which field starts */
  var pSchema   : UnsafePointer<CChar>? = nil
  var pHost     : UnsafePointer<CChar>? = nil
  var pPort     : UnsafePointer<CChar>? = nil
  var pPath     : UnsafePointer<CChar>? = nil
  var pQuery    : UnsafePointer<CChar>? = nil
  var pFragment : UnsafePointer<CChar>? = nil
  var pUserInfo : UnsafePointer<CChar>? = nil

  var lSchema   : Int16 = 0
  var lHost     : Int16 = 0
  var lPort     : Int16 = 0
  var lPath     : Int16 = 0
  var lQuery    : Int16 = 0
  var lFragment : Int16 = 0
  var lUserInfo : Int16 = 0
  
  mutating func setField(field: HTTPParserURLFields,
                         ptr:   UnsafePointer<CChar>,
                         len:   Int16)
  {
    switch field {
      case HTTPParserURLFields.SCHEMA:
        pSchema = ptr
        lSchema = len
      case HTTPParserURLFields.HOST:
        pHost = ptr
        lHost = len
      case HTTPParserURLFields.PORT:
        pPort = ptr
        lPort = len
      case HTTPParserURLFields.PATH:
        pPath = ptr
        lPath = len
      case HTTPParserURLFields.QUERY:
        pQuery = ptr
        lQuery = len
      case HTTPParserURLFields.FRAGMENT:
        pFragment = ptr
        lFragment = len
      case HTTPParserURLFields.USERINFO:
        pUserInfo = ptr
        lUserInfo = len
      default:
        fatalError("unexpected URL field")
    }
    field_set.insert(field)
  }
}
