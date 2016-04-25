//
//  HTTPParser.swift
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

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

let HTTP_PARSER_STRICT   = false
let HTTP_MAX_HEADER_SIZE = (80*1024)

// HTTP_METHOD_MAP - is HTTPMethod enum
// HTTP_ERRNO_MAP  - is HTTPError  enum

// enum in original
public struct HTTPParserOptions : OptionSetType {
  // Use: let justChunked = HTTPParserOptions.F_CHUNKED
  //      let two : HTTPParserOptions = [ F_CHUNKED, F_CONNECTION_CLOSE]
  //      two.contains(.F_CONNECTION_CLOSE)
  
  public let rawValue : Int

  public init(rawValue: Int = 0) {
    self.rawValue = rawValue
  }
  
  static let F_CHUNKED               = HTTPParserOptions(rawValue: 1 << 0)
  static let F_CONNECTION_KEEP_ALIVE = HTTPParserOptions(rawValue: 1 << 1)
  static let F_CONNECTION_CLOSE      = HTTPParserOptions(rawValue: 1 << 2)
  static let F_CONNECTION_UPGRADE    = HTTPParserOptions(rawValue: 1 << 3)
  static let F_TRAILING              = HTTPParserOptions(rawValue: 1 << 4)
  static let F_UPGRADE               = HTTPParserOptions(rawValue: 1 << 5)
  static let F_SKIPBODY              = HTTPParserOptions(rawValue: 1 << 6)
}

public enum HTTPParserType {
  case HTTP_REQUEST
  case HTTP_RESPONSE
  case HTTP_BOTH
}

typealias http_data_cb = ( HTTPParser, UnsafePointer<CChar>, size_t) -> Int
typealias http_cb      = ( HTTPParser ) -> Int

public class HTTPParser {

  // MARK: - http_parser
  
  var type           : HTTPParserType
  var flags          = HTTPParserOptions()
  var state          : ParserState       = .s_dead
  var header_state   : ParserHeaderState = .h_general
  var index          : Int   = 0 // this is UInt8, but Int can be used as an idx
  
  var nread          : Int   = 0
  var content_length : Int   = 0
  
  // READ-ONLY
  var http_major     : Int16?      = nil
  var http_minor     : Int16?      = nil
  var status_code    : Int16?      = nil // responses only
  var method         : HTTPMethod! = nil // requests only
  var error          : HTTPError   = .OK // use an optional for OK?

  var statusCode : HTTPStatus? {
    guard let v = status_code else { return nil }
    return HTTPStatus(Int(v))
  }
  
  var upgrade        = false
  
  var data : Any? = nil
  
  
  // MARK: - http_parser_settings (this is global in here, per execute in orig)
  
  var onMessageBegin    : http_cb?      = nil
  var onURL             : http_data_cb? = nil
  var onStatus          : http_data_cb? = nil
  var onHeaderField     : http_data_cb? = nil
  var onHeaderValue     : http_data_cb? = nil
  var onHeadersComplete : http_cb?      = nil
  var onBody            : http_data_cb? = nil
  var onMessageComplete : http_cb?      = nil
  
  /* When on_chunk_header is called, the current chunk length is stored
   * in parser->content_length.
   */
  var onChunkHeader     : http_cb? = nil
  var onChunkComplete   : http_cb? = nil
  
  
  // MARK: - Init
  
  public init(type: HTTPParserType = .HTTP_BOTH) { // http_parser_init
    self.type = type
    
    // start_state
    self.state = startState
  }
  
  
  // MARK: - Callbacks
  
  /// Run the notify callback FOR, returning ER if it fails
  func CALLBACK_NOTIFY_(cb: http_cb?,
                        inout _ CURRENT_STATE : ParserState,
                        _ ER: size_t)
       -> size_t?
  {
    guard let cb = cb else { return nil }
    
    self.state = CURRENT_STATE
    if cb(self) != 0 {
      // FIXME: base this on cb / pass in error
      error = .CB_message_begin
    }
    
    CURRENT_STATE = self.state
    // The original macro has a hard return!
    return error != .OK ? ER : nil
  }
  
  /// Run the notify callback FOR and consume the current byte
  func CALLBACK_NOTIFY(cb: http_cb?,
                       inout _ CURRENT_STATE : ParserState,
                       _ p:    UnsafePointer<CChar>,
                       _ data: UnsafePointer<CChar>)
    -> size_t?
  {
    let len = p - data + 1
    return CALLBACK_NOTIFY_(cb, &CURRENT_STATE, len)
  }
  
  /// Run the notify callback FOR and don't consume the current byte
  func CALLBACK_NOTIFY_NOADVANCE(cb: http_cb?,
                                 inout _ CURRENT_STATE : ParserState,
                                 _ p:    UnsafePointer<CChar>,
                                 _ data: UnsafePointer<CChar>)
    -> size_t?
  {
    let len = p - data
    return CALLBACK_NOTIFY_(cb, &CURRENT_STATE, len)
  }
  
  /// Run data callback FOR with LEN bytes, returning ER if it fails
  func CALLBACK_DATA_(cb: http_data_cb?,
                      inout _ mark : UnsafePointer<CChar>,
                      inout _ CURRENT_STATE : ParserState,
                      _ len: size_t, _ ER: size_t)
       -> size_t?
  {
    assert(error == .OK)
    
    if mark != nil {
      if let cb = cb {
        self.state = CURRENT_STATE
        if 0 != cb(self, mark, len) {
          // TODO: base this on cb
          error = .CB_message_begin // SET_ERRNO(HPE_CB_##FOR)
        }
        CURRENT_STATE = self.state // in case the CB patched it
        
        /* We either errored above or got paused; get out */
        if error != .OK {
          return ER
        }
      }
      
      mark = nil // inout, propagates to caller
    }
    
    return nil
  }
  
  /// Run the data callback FOR and consume the current byte
  func CALLBACK_DATA(cb: http_data_cb?,
                     inout _ mark : UnsafePointer<CChar>,
                     inout _ CURRENT_STATE : ParserState,
                     _ p:    UnsafePointer<CChar>,
                     _ data: UnsafePointer<CChar>) -> size_t?
  {
    return CALLBACK_DATA_(cb, &mark, &CURRENT_STATE, p - mark, p - data + 1)
  }
  /// Run the data callback FOR and consume the current byte
  func CALLBACK_DATA_NOADVANCE(cb: http_data_cb?,
                     inout _ mark : UnsafePointer<CChar>,
                     inout _ CURRENT_STATE : ParserState,
                     _ p:    UnsafePointer<CChar>,
                     _ data: UnsafePointer<CChar>) -> size_t?
  {
    return CALLBACK_DATA_(cb, &mark, &CURRENT_STATE, p - mark, p - data)
  }
  
  
  // MARK: - Execute
  
  /// Executes the parser. Returns number of parsed bytes. Sets
  /// `error` on error.
  public func execute(data: UnsafePointer<CChar>, _ len: size_t) -> size_t {
    /* We're in an error state. Don't bother doing anything. */
    guard error != .OK else { return 0 }
    
    var p             = data
    var CURRENT_STATE = self.state
    
    if (len == 0) {
      switch CURRENT_STATE {
        case .s_body_identity_eof:
          /* Use of CALLBACK_NOTIFY() here would erroneously return 1 byte read if
           * we got paused.
           */
          let len = CALLBACK_NOTIFY_NOADVANCE(onMessageComplete, &CURRENT_STATE,
                                              p, data)
          if let len = len { return len } // error
          return 0
          
        case .s_dead:             return 0
        case .s_start_req_or_res: return 0
        case .s_start_res:        return 0
        case .s_start_req:        return 0
        
        default:
          error = .INVALID_EOF_STATE
          return 1 // hu?
      }
    }
    
    
    // collect markers
    
    var header_field_mark : UnsafePointer<CChar> = nil
    var header_value_mark : UnsafePointer<CChar> = nil
    var url_mark          : UnsafePointer<CChar> = nil
    var body_mark         : UnsafePointer<CChar> = nil
    var status_mark       : UnsafePointer<CChar> = nil
    
    switch CURRENT_STATE {
      case .s_header_field: header_field_mark = data
      case .s_header_value: header_value_mark = data
      case .s_res_status:   status_mark       = data
      
      case .s_req_path:               fallthrough
      case .s_req_schema:             fallthrough
      case .s_req_schema_slash:       fallthrough
      case .s_req_schema_slash_slash: fallthrough
      case .s_req_server_start:       fallthrough
      case .s_req_server:             fallthrough
      case .s_req_server_with_at:     fallthrough
      case .s_req_query_string_start: fallthrough
      case .s_req_query_string:       fallthrough
      case .s_req_fragment_start:     fallthrough
      case .s_req_fragment:
        url_mark = data
      
      default: break
    }
    
    // `MARK` macro in original:
    //    #define MARK(FOR) if (!FOR##_mark)  FOR##_mark = p;
    
    
    func RETURN(V: size_t) -> size_t {
      self.state = CURRENT_STATE
      return V
    }
    func gotoError(e : HTTPError? = nil) -> size_t {
      if let e = e { error = e }
      if error == .OK { error = .UNKNOWN }
      return RETURN(p - data)
    }
    
    func UPDATE_STATE(state: ParserState) {
      CURRENT_STATE = state
    }
    
    var ch : CChar

    // REEXECUTE macro:
    //   if let len = gotoReexecute() { return len } // error?
    func gotoReexecute() -> size_t? {
      /* reexecute: label */
      
      switch CURRENT_STATE {
        case .s_dead:
          /* this state is used after a 'Connection: close' message
           * the parser will error out if it reads another message
           */
          if ch == CR || ch == LF { break }
          return gotoError(.CLOSED_CONNECTION)

        case .s_start_req_or_res:
          if ch == CR || ch == LF { break }
          
          self.flags          = HTTPParserOptions()
          self.content_length = Int.max // was: ULLONG_MAX
          
          if ch == 72 /* 'H' */ {
            UPDATE_STATE(.s_res_or_resp_H);
            
            let len = CALLBACK_NOTIFY(onMessageBegin, &CURRENT_STATE, p, data)
            if let len = len { return len } // error
          }
          else {
            self.type = .HTTP_REQUEST;
            UPDATE_STATE(.s_start_req)
            
            gotoReexecute()
          }
        
        case .s_res_or_resp_H:
          if ch == 84 /* 'T' */ {
            self.type = .HTTP_RESPONSE
            UPDATE_STATE(.s_res_HT)
          }
          else {
            if ch != 69 /* 'E' */ {
              error = .INVALID_CONSTANT
              return gotoError()
            }

            self.type   = .HTTP_REQUEST
            self.method = .HEAD
            index = 2
            UPDATE_STATE(.s_req_method)
          }

        case .s_start_res:
          self.flags          = HTTPParserOptions()
          self.content_length = Int.max // was: ULLONG_MAX

          switch (ch) {
            case 72 /* 'H' */: UPDATE_STATE(.s_res_H);
            case CR: break
            case LF: break
            default: return gotoError(.INVALID_CONSTANT)
          }
          
          let len = CALLBACK_NOTIFY(onMessageBegin, &CURRENT_STATE, p, data)
          if let len = len { return len } // error
        
        case .s_res_H:
          STRICT_CHECK(ch != 84 /* 'T' */)
          UPDATE_STATE(.s_res_HT)

        case .s_res_HT:
          STRICT_CHECK(ch != 84 /* 'T' */);
          UPDATE_STATE(.s_res_HTT);
          break;

        case .s_res_HTT:
          STRICT_CHECK(ch != 80 /* 'P' */);
          UPDATE_STATE(.s_res_HTTP);
          break;

        case .s_res_HTTP:
          STRICT_CHECK(ch != 47 /* '/' */);
          UPDATE_STATE(.s_res_first_http_major);
          break;

        case .s_res_first_http_major:
          if ch < 48 /* '0' */ || ch > 57 /* '9' */ {
            return gotoError(.INVALID_VERSION)
          }

          http_major = Int16(ch - 48) /* '0' */;
          UPDATE_STATE(.s_res_http_major);

        /* major HTTP version or dot */
        case .s_res_http_major:
          if ch == 46 /* '.' */ {
            UPDATE_STATE(.s_res_first_http_minor);
            break
          }
          
          guard IS_NUM(ch) else { return gotoError(.INVALID_VERSION) }
          
          assert(self.http_major != nil)
          self.http_major! *= Int16(10)
          self.http_major! += Int16(ch - 48 /* '0' */)
          
          guard self.http_major < 1000 else {
            return gotoError(.INVALID_VERSION)
          }

        /* first digit of minor HTTP version */
        case .s_res_first_http_minor:
          if !IS_NUM(ch) { return gotoError(.INVALID_VERSION) }

          self.http_minor = Int16(ch - 48 /* '0' */);
          UPDATE_STATE(.s_res_http_minor);

        /* minor HTTP version or end of request line */
        case .s_res_http_minor:
          if ch == 32 /* ' ' */ {
            UPDATE_STATE(.s_res_first_status_code);
            break
          }
          
          guard IS_NUM(ch) else { return gotoError(.INVALID_VERSION) }
          
          assert(self.http_minor != nil)
          self.http_minor! *= Int16(10)
          self.http_minor! += Int16(ch - 48 /* '0' */)
          
          guard self.http_minor < 1000 else { return gotoError(.INVALID_VERSION) }

        case .s_res_first_status_code:
          if !IS_NUM(ch) {
            if ch == 32 /* ' ' */ { break }

            return gotoError(.INVALID_STATUS)
          }
          self.status_code = Int16(ch - 48 /* '0' */)
          UPDATE_STATE(.s_res_status_code);

        case .s_res_status_code:
          if !IS_NUM(ch) {
            switch (ch) {
              case 32 /* ' ' */: UPDATE_STATE(.s_res_status_start);
              case CR:           UPDATE_STATE(.s_res_line_almost_done);
              case LF:           UPDATE_STATE(.s_header_field_start)
              default:           return gotoError(.INVALID_STATUS)
            }
            break
          }

          assert(self.status_code != nil)
          self.status_code! *= Int16(10)
          self.status_code! += Int16(ch - 48 /* '0' */)

          guard status_code < 1000 else { return gotoError(.INVALID_STATUS) }

        case .s_res_status_start:
          if ch == CR { UPDATE_STATE(.s_res_line_almost_done); break }
          if ch == LF { UPDATE_STATE(.s_header_field_start);   break }
          if status_mark == nil { status_mark = p } // MARK(status);
          UPDATE_STATE(.s_res_status);
          self.index = 0;

        case .s_res_status:
          if ch == CR {
            UPDATE_STATE(.s_res_line_almost_done)
            //CALLBACK_DATA(status)
            let rc = CALLBACK_DATA(onStatus, &status_mark, &CURRENT_STATE,
                                   p, data)
            if let rc = rc { return rc } // error
            break
          }
          
          if ch == LF {
            UPDATE_STATE(.s_header_field_start)
            let rc = CALLBACK_DATA(onStatus, &status_mark, &CURRENT_STATE,
                                   p, data)
            if let rc = rc { return rc } // error
            break
          }

        case .s_res_line_almost_done:
          STRICT_CHECK(ch != LF)
          UPDATE_STATE(.s_header_field_start)

        case .s_start_req:
          if ch == CR || ch == LF { break }

          self.flags = HTTPParserOptions()
          self.content_length = Int.max // was: ULLONG_MAX;
          
          guard IS_ALPHA(ch) else { return gotoError(.INVALID_METHOD) }
          
          self.method = nil
          self.index  = 1;
          switch ch {
            case cA: self.method = .ACL
            case cB: self.method = .BIND
            case cC: self.method = .CONNECT /* or COPY, CHECKOUT */
            case cD: self.method = .DELETE
            case cG: self.method = .GET
            case cH: self.method = .HEAD
            case cL: self.method = .LOCK /* or LINK */
            case cM: self.method = .MKCOL
               /* or MOVE, MKACTIVITY, MERGE, M-SEARCH, MKCALENDAR */
            case cN: self.method = .NOTIFY
            case cO: self.method = .OPTIONS
            case cP: self.method = .POST
              /* or PROPFIND|PROPPATCH|PUT|PATCH|PURGE */

            case cR: self.method = .REPORT /* or REBIND */
            case cS: self.method = .SUBSCRIBE /* or SEARCH */
            case cT: self.method = .TRACE
            case cU: self.method = .UNLOCK
              /* or UNSUBSCRIBE, UNBIND, UNLINK */
            default:
              return gotoError(.INVALID_METHOD)
          }
          UPDATE_STATE(.s_req_method);
          
          // CALLBACK_NOTIFY(message_begin);
          let len = CALLBACK_NOTIFY(onMessageBegin, &CURRENT_STATE, p, data)
          if let len = len { return len } // error
          
          break;

        case .s_req_method:
          guard ch != 0 else { return gotoError(.INVALID_METHOD) }
          
          //const char *matcher = method_strings[self.method];
          let matcher = self.method.csMethod
          
          
          if (ch == cSPACE && matcher[self.index] == 0) {
            UPDATE_STATE(.s_req_spaces_before_url);
          } else if (ch == matcher[self.index]) {
            /* nada */
          } else if (self.method == .CONNECT) {
            if (self.index == 1 && ch == cH) {
              self.method = .CHECKOUT;
            } else if (self.index == 2  && ch == cP) {
              self.method = .COPY;
            } else {
              return gotoError(.INVALID_METHOD)
            }
          } else if (self.method == .MKCOL) {
            if (self.index == 1 && ch == cO) {
              self.method = .MOVE;
            } else if (self.index == 1 && ch == cE) {
              self.method = .MERGE;
            } else if (self.index == 1 && ch == cDASH) {
              self.method = .MSEARCH;
            } else if (self.index == 2 && ch == cA) {
              self.method = .MKACTIVITY;
            } else if (self.index == 3 && ch == cA) {
              self.method = .MKCALENDAR;
            } else {
              return gotoError(.INVALID_METHOD)
            }
          } else if (self.method == .SUBSCRIBE) {
            if (self.index == 1 && ch == cE) {
              self.method = .SEARCH;
            } else {
              return gotoError(.INVALID_METHOD)
            }
          } else if (self.method == .REPORT) {
              if (self.index == 2 && ch == cB) {
                self.method = .REBIND;
              } else {
                return gotoError(.INVALID_METHOD)
              }
          } else if (self.index == 1) {
            if (self.method == .POST) {
              if (ch == cR) {
                self.method = .PROPFIND; /* or HTTP_PROPPATCH */
              } else if (ch == cU) {
                self.method = .PUT; /* or HTTP_PURGE */
              } else if (ch == cA) {
                self.method = .PATCH;
              } else {
                return gotoError(.INVALID_METHOD)
              }
            } else if (self.method == .LOCK) {
              if (ch == cI) {
                self.method = .LINK;
              } else {
                return gotoError(.INVALID_METHOD)
              }
            }
          } else if (self.index == 2) {
            if (self.method == .PUT) {
              if (ch == cR) {
                self.method = .PURGE;
              } else {
                return gotoError(.INVALID_METHOD)
              }
            } else if (self.method == .UNLOCK) {
              if (ch == cS) {
                self.method = .UNSUBSCRIBE;
              } else if(ch == cB) {
                self.method = .UNBIND;
              } else {
                return gotoError(.INVALID_METHOD)
              }
            } else {
              return gotoError(.INVALID_METHOD)
            }
          } else if (self.index == 4 && self.method == .PROPFIND && ch == cP) {
            self.method = .PROPPATCH;
          } else if (self.index == 3 && self.method == .UNLOCK && ch == cI) {
            self.method = .UNLINK;
          } else {
            return gotoError(.INVALID_METHOD)
          }

          self.index += 1

        case .s_req_spaces_before_url:
          if ch == cSPACE { break }
          
          if url_mark == nil { url_mark = p } // MARK(url)
          if (self.method == .CONNECT) {
            UPDATE_STATE(.s_req_server_start);
          }
          
          UPDATE_STATE(parse_url_char(CURRENT_STATE, ch))
          if (CURRENT_STATE == .s_dead) { return gotoError(.INVALID_URL) }


        case .s_req_schema:             fallthrough
        case .s_req_schema_slash:       fallthrough
        case .s_req_schema_slash_slash: fallthrough
        case .s_req_server_start:
          switch ch {
            /* No whitespace allowed here */
            case cSPACE: fallthrough
            case CR:     fallthrough
            case LF:     return gotoError(.INVALID_URL)
            default:
              UPDATE_STATE(parse_url_char(CURRENT_STATE, ch))
              if CURRENT_STATE == .s_dead { return gotoError(.INVALID_URL) }
          }

      case .s_req_server:             fallthrough
      case .s_req_server_with_at:     fallthrough
      case .s_req_path:               fallthrough
      case .s_req_query_string_start: fallthrough
      case .s_req_query_string:       fallthrough
      case .s_req_fragment_start:     fallthrough
      case .s_req_fragment:
        switch ch {
          case cSPACE:
            UPDATE_STATE(.s_req_http_start)
            //CALLBACK_DATA(url);
            let rc = CALLBACK_DATA(onURL, &url_mark, &CURRENT_STATE, p, data)
            if let rc = rc { return rc } // error
          
          case CR: fallthrough
          case LF:
            self.http_major = 0
            self.http_minor = 9
            UPDATE_STATE(ch == CR
                         ? .s_req_line_almost_done
                         : .s_header_field_start)
            // CALLBACK_DATA(url)
            let rc = CALLBACK_DATA(onURL, &url_mark, &CURRENT_STATE, p, data)
            if let rc = rc { return rc } // error

          default:
            UPDATE_STATE(parse_url_char(CURRENT_STATE, ch))
            if CURRENT_STATE == .s_dead { return gotoError(.INVALID_URL) }
        }

        case .s_req_http_start:
          switch ch {
            case cH:     UPDATE_STATE(.s_req_http_H);
            case cSPACE: break;
            default:     return gotoError(.INVALID_CONSTANT)
          }
        
        case .s_req_http_H:
          STRICT_CHECK(ch != cT)
          UPDATE_STATE(.s_req_http_HT)

        case .s_req_http_HT:
          STRICT_CHECK(ch != cT)
          UPDATE_STATE(.s_req_http_HTT)

        case .s_req_http_HTT:
          STRICT_CHECK(ch != cP)
          UPDATE_STATE(.s_req_http_HTTP)

        case .s_req_http_HTTP:
          STRICT_CHECK(ch != cSLASH)
          UPDATE_STATE(.s_req_first_http_major)

        /* first digit of major HTTP version */
        case .s_req_first_http_major:
          if ch < c1 || ch > c9 { return gotoError(.INVALID_VERSION) }

          self.http_major = Int16(ch - c0)
          UPDATE_STATE(.s_req_http_major)

        /* major HTTP version or dot */
        case .s_req_http_major:
          if ch == cDOT {
            UPDATE_STATE(.s_req_first_http_minor)
            break;
          }
          guard IS_NUM(ch) else { return gotoError(.INVALID_VERSION) }
          
          assert(self.http_major != nil)
          self.http_major! *= 10;
          self.http_major! += Int16(ch - c0);
          
          guard self.http_major < 1000 else {
            return gotoError(.INVALID_VERSION)
          }

        /* first digit of minor HTTP version */
        case .s_req_first_http_minor:
          guard IS_NUM(ch) else { return gotoError(.INVALID_VERSION) }
          self.http_minor = Int16(ch - c0)
          UPDATE_STATE(.s_req_http_minor)

        /* minor HTTP version or end of request line */
        case .s_req_http_minor:
          if ch == CR { UPDATE_STATE(.s_req_line_almost_done); break }
          if ch == LF { UPDATE_STATE(.s_header_field_start);   break }

          /* XXX allow spaces after digit? */
          
          guard IS_NUM(ch) else { return gotoError(.INVALID_VERSION) }

          assert(self.http_minor != nil)
          self.http_minor! *= 10
          self.http_minor! += ch - c0

          guard self.http_minor < 1000 else {
            return gotoError(.INVALID_VERSION)
          }

        /* end of request line */
        case .s_req_line_almost_done:
          guard ch == LF else { return gotoError(.LF_EXPECTED) }
          UPDATE_STATE(.s_header_field_start);

        case .s_header_field_start:
          if ch == CR { UPDATE_STATE(.s_headers_almost_done); break }

          if ch == LF {
            /* they might be just sending \n instead of \r\n so this would be
             * the second \n to denote the end of headers*/
            UPDATE_STATE(.s_headers_almost_done)
            if let len = gotoReexecute() { return len } // error?
          }

          let c = TOKEN(ch)
          guard c != 0 else { return gotoError(.INVALID_HEADER_TOKEN) }


          // MARK(header_field);
          if header_field_mark == nil { header_field_mark = p }

          self.index = 0;
          UPDATE_STATE(.s_header_field)

          switch c {
            case cc: self.header_state = .h_C
            case cp: self.header_state = .h_matching_proxy_connection
            case ct: self.header_state = .h_matching_transfer_encoding
            case cu: self.header_state = .h_matching_upgrade
            default: self.header_state = .h_general
          }

        case .s_header_field:
          let start = p
          while p != (data + len) {
            ch = p.memory
            let c = TOKEN(ch)
            if c == 0 { break }

            switch self.header_state {
              case .h_general: break

              case .h_C:
                self.index += 1
                self.header_state = (c == co ? .h_CO : .h_general)

              case .h_CO:
                self.index += 1
                self.header_state = (c == cn ? .h_CON : .h_general)

              case .h_CON:
                self.index += 1
                switch c {
                  case cn: self.header_state = .h_matching_connection
                  case ct: self.header_state = .h_matching_content_length
                  default: self.header_state = .h_general
                }

              /* connection */

              case .h_matching_connection:
                self.index += 1
                if self.index > lCONNECTION || c != CONNECTION[self.index] {
                  self.header_state = .h_general;
                } else if self.index == lCONNECTION - 1 {
                  self.header_state = .h_connection;
                }
                break;

              /* proxy-connection */

              case .h_matching_proxy_connection:
                self.index += 1
                if (self.index > lPROXY_CONNECTION
                    || c != PROXY_CONNECTION[self.index]) {
                  self.header_state = .h_general;
                } else if self.index == lPROXY_CONNECTION-1 {
                  self.header_state = .h_connection;
                }

              /* content-length */

              case .h_matching_content_length:
                self.index += 1
                if (self.index > lCONTENT_LENGTH
                    || c != CONTENT_LENGTH[self.index]) {
                  self.header_state = .h_general;
                } else if self.index == lCONTENT_LENGTH-1 {
                  self.header_state = .h_content_length;
                }

              /* transfer-encoding */

              case .h_matching_transfer_encoding:
                self.index += 1
                if (self.index > lTRANSFER_ENCODING
                    || c != TRANSFER_ENCODING[self.index]) {
                  self.header_state = .h_general;
                } else if self.index == lTRANSFER_ENCODING-1 {
                  self.header_state = .h_transfer_encoding;
                }

              /* upgrade */

              case .h_matching_upgrade:
                self.index += 1
                
                if self.index > lUPGRADE || c != UPGRADE[self.index] {
                  self.header_state = .h_general;
                } else if self.index == lUPGRADE-1 {
                  self.header_state = .h_upgrade;
                }

              case .h_connection:        fallthrough
              case .h_content_length:    fallthrough
              case .h_transfer_encoding: fallthrough
              case .h_upgrade:
                if ch != cSPACE { self.header_state = .h_general }

              default:
                assert(false, "Unknown header_state")
            }
            
            p += 1
          }

          COUNT_HEADER_SIZE(p - start)

          if p == data + len {
            p -= 1
            break
          }

          if ch == cCOLON {
            UPDATE_STATE(.s_header_value_discard_ws);
            
            // CALLBACK_DATA(header_field);
            let rc = CALLBACK_DATA(onHeaderField, &header_field_mark,
                                   &CURRENT_STATE, p, data)
            if let rc = rc { return rc } // error
            break
          }

          return gotoError(.INVALID_HEADER_TOKEN)

        case .s_header_value_discard_ws:
          if ch == cSPACE || ch == cTAB { break }
          
          if ch == CR {
            UPDATE_STATE(.s_header_value_discard_ws_almost_done)
            break
          }
          if ch == LF { UPDATE_STATE(.s_header_value_discard_lws); break }

          /* FALLTHROUGH */
          fallthrough

        case .s_header_value_start:
          // MARK(header_value);
          if header_value_mark == nil { header_value_mark = p }
          
          UPDATE_STATE(.s_header_value)
          self.index = 0

          let c = LOWER(ch)

          switch self.header_state {
            case .h_upgrade:
              self.flags.insert(.F_UPGRADE)
              self.header_state = .h_general;

            case .h_transfer_encoding:
              /* looking for 'Transfer-Encoding: chunked' */
              if (cc == c) {
                self.header_state = .h_matching_transfer_encoding_chunked
              } else {
                self.header_state = .h_general
              }

            case .h_content_length:
              guard IS_NUM(ch) else { return gotoError(.INVALID_CONTENT_LENGTH)}
              self.content_length = ch - c0;

            case .h_connection:
              /* looking for 'Connection: keep-alive' */
              if (c == ck) {
                self.header_state = .h_matching_connection_keep_alive;
              /* looking for 'Connection: close' */
              } else if (c == cc) {
                self.header_state = .h_matching_connection_close;
              } else if (c == cu) {
                self.header_state = .h_matching_connection_upgrade;
              } else {
                self.header_state = .h_matching_connection_token;
              }

            /* Multi-value `Connection` header */
            case .h_matching_connection_token_start: break

            default: self.header_state = .h_general; break
          }

        case .s_header_value:
          let start   = p
          var h_state = self.header_state
          
          while p != data + len {
            ch = p.memory
            
            if (ch == CR) {
              UPDATE_STATE(.s_header_almost_done);
              self.header_state = h_state;
              // CALLBACK_DATA(header_value);
              let rc = CALLBACK_DATA(onHeaderValue, &header_value_mark,
                                     &CURRENT_STATE, p, data)
              if let rc = rc { return rc } // error
              break;
            }

            if (ch == LF) {
              UPDATE_STATE(.s_header_almost_done);
              COUNT_HEADER_SIZE(p - start);
              self.header_state = h_state;
              // CALLBACK_DATA_NOADVANCE(header_value);
              let rc = CALLBACK_DATA_NOADVANCE(onHeaderValue,
                                               &header_value_mark,
                                               &CURRENT_STATE, p, data)
              if let rc = rc { return rc } // error
              
              if let len = gotoReexecute() { return len } // error?
            }

            let c = LOWER(ch)

            switch h_state {
              case .h_general:
                var limit : size_t = data + len - p;

                limit = min(limit, HTTP_MAX_HEADER_SIZE);

                // p_cr = (const char*) memchr(p, CR, limit);
                // p_lf = (const char*) memchr(p, LF, limit);
                let p_cr = UnsafePointer<CChar>(memchr(p, Int32(CR), limit))
                let p_lf = UnsafePointer<CChar>(memchr(p, Int32(LF), limit))
                if p_cr != nil {
                  if p_lf != nil && p_cr >= p_lf {
                    p = p_lf
                  } else {
                    p = p_cr
                  }
                } else if p_lf != nil {
                  p = p_lf
                } else {
                  p = data + len;
                }
                p -= 1

              case .h_connection: fallthrough
              case .h_transfer_encoding:
                assert(false, "Shouldn't get here.")

              case .h_content_length:
                if ch == cSPACE { break }

                guard IS_NUM(ch) else {
                  self.header_state = h_state;
                  return gotoError(.INVALID_CONTENT_LENGTH)
                }

                var t = Int(self.content_length)
                t *= 10
                t += Int(ch - c0)

                /* Overflow? Test against a conservative limit for simplicity. */
                // HH: was ULLONG_MAX
                if (Int.max - 10) / 10 < self.content_length {
                  self.header_state = h_state;
                  return gotoError(.INVALID_CONTENT_LENGTH)
                }

                self.content_length = Int(t)

              /* Transfer-Encoding: chunked */
              case .h_matching_transfer_encoding_chunked:
                self.index += 1
                if self.index > lCHUNKED || c != CHUNKED[self.index] {
                  h_state = .h_general
                } else if self.index == lCHUNKED-1 {
                  h_state = .h_transfer_encoding_chunked
                }

              case .h_matching_connection_token_start:
                /* looking for 'Connection: keep-alive' */
                if c == ck {
                  h_state = .h_matching_connection_keep_alive
                /* looking for 'Connection: close' */
                } else if c == cc {
                  h_state = .h_matching_connection_close
                } else if c == cu {
                  h_state = .h_matching_connection_upgrade
                } else if STRICT_TOKEN(c) != 0 {
                  h_state = .h_matching_connection_token
                } else if c == cSPACE || c == cTAB {
                  /* Skip lws */
                } else {
                  h_state = .h_general
                }

              /* looking for 'Connection: keep-alive' */
              case .h_matching_connection_keep_alive:
                self.index += 1;
                if self.index > lKEEP_ALIVE || c != KEEP_ALIVE[self.index] {
                  h_state = .h_matching_connection_token
                } else if self.index == lKEEP_ALIVE-1 {
                  h_state = .h_connection_keep_alive
                }

              /* looking for 'Connection: close' */
              case .h_matching_connection_close:
                self.index += 1
                if self.index > lCLOSE || c != CLOSE[self.index] {
                  h_state = .h_matching_connection_token
                } else if self.index == lCLOSE-1 {
                  h_state = .h_connection_close
                }

              /* looking for 'Connection: upgrade' */
              case .h_matching_connection_upgrade:
                self.index += 1
                if self.index > lUPGRADE || c != UPGRADE[self.index] {
                  h_state = .h_matching_connection_token
                } else if self.index == lUPGRADE-1 {
                  h_state = .h_connection_upgrade
                }

              case .h_matching_connection_token:
                if ch == cCOMMA {
                  h_state = .h_matching_connection_token_start
                  self.index = 0
                }

              case .h_transfer_encoding_chunked:
                if ch != cSPACE { h_state = .h_general }
                break;

              case .h_connection_keep_alive: fallthrough
              case .h_connection_close:      fallthrough
              case .h_connection_upgrade:
                if ch == cCOMMA {
                  if h_state == .h_connection_keep_alive {
                    self.flags.insert(.F_CONNECTION_KEEP_ALIVE)
                  } else if h_state == .h_connection_close {
                    self.flags.insert(.F_CONNECTION_CLOSE)
                  } else if h_state == .h_connection_upgrade {
                    self.flags.insert(.F_CONNECTION_UPGRADE)
                  }
                  h_state = .h_matching_connection_token_start
                  self.index = 0;
                } else if ch != cSPACE {
                  h_state = .h_matching_connection_token
                }

              default:
                UPDATE_STATE(.s_header_value)
                h_state = .h_general
            }
            
            p += 1
          }
          self.header_state = h_state;

          COUNT_HEADER_SIZE(p - start);

          if (p == data + len) {
            p -= 1
          }

        case .s_header_almost_done:
          STRICT_CHECK(ch != LF)
          UPDATE_STATE(.s_header_value_lws)
          
        case .s_header_value_lws:
          if ch == cSPACE || ch == cTAB {
            UPDATE_STATE(.s_header_value_start)
            if let len = gotoReexecute() { return len }
          }

          /* finished the header */
          switch self.header_state {
            case .h_connection_keep_alive:
              self.flags.insert(.F_CONNECTION_KEEP_ALIVE)
            case .h_connection_close:
              self.flags.insert(.F_CONNECTION_CLOSE)
            case .h_transfer_encoding_chunked:
              self.flags.insert(.F_CHUNKED)
            case .h_connection_upgrade:
              self.flags.insert(.F_CONNECTION_UPGRADE)
            default: break;
          }

          UPDATE_STATE(.s_header_field_start)
          if let len = gotoReexecute() { return len }

        case .s_header_value_discard_ws_almost_done:
          STRICT_CHECK(ch != LF)
          UPDATE_STATE(.s_header_value_discard_lws)

        case .s_header_value_discard_lws:
          if (ch == cSPACE || ch == cTAB) {
            UPDATE_STATE(.s_header_value_discard_ws)
            break
          } else {
            switch self.header_state {
              case .h_connection_keep_alive:
                self.flags.insert(.F_CONNECTION_KEEP_ALIVE)
              case .h_connection_close:
                self.flags.insert(.F_CONNECTION_CLOSE)
              case .h_connection_upgrade:
                self.flags.insert(.F_CONNECTION_UPGRADE)
              case .h_transfer_encoding_chunked:
                self.flags.insert(.F_CHUNKED)
              default: break
            }

            /* header value was empty */
            // MARK(header_value);
            if header_value_mark == nil { header_value_mark = p }
            UPDATE_STATE(.s_header_field_start);
            
            let rc = CALLBACK_DATA_NOADVANCE(onHeaderValue,
                                             &header_value_mark,
                                             &CURRENT_STATE, p, data)
            if let rc = rc { return rc } // error
            
            if let len = gotoReexecute() { return len }
          }
          // hh: TODO: I think this was a fallthrough, is that right?
          //     might be a reexecute issue
          assert(false, "reexecute fallthrough")

        case .s_headers_almost_done:
          STRICT_CHECK(ch != LF)

          if self.flags.contains(.F_TRAILING) {
            /* End of a chunked request */
            UPDATE_STATE(.s_message_done);
            let len = CALLBACK_NOTIFY_NOADVANCE(onChunkComplete, &CURRENT_STATE,
                                                p, data)
            if let len = len { return len } // error
            if let len = gotoReexecute() { return len }
          }

          UPDATE_STATE(.s_headers_done);

          /* Set this here so that on_headers_complete() callbacks can see it */
          self.upgrade =
            ((self.flags.contains(.F_UPGRADE)
              && self.flags.contains(.F_CONNECTION_UPGRADE))
             || self.method == .CONNECT)
          
          /* Here we call the headers_complete callback. This is somewhat
           * different than other callbacks because if the user returns 1, we
           * will interpret that as saying that this message has no body. This
           * is needed for the annoying case of recieving a response to a HEAD
           * request.
           *
           * We'd like to use CALLBACK_NOTIFY_NOADVANCE() here but we cannot, so
           * we have to simulate it by handling a change in errno below.
           */
          if let cb = onHeadersComplete {
            switch cb(self) {
              case 0:
                break;

              case 1:
                self.flags.insert(.F_SKIPBODY)
                break;

              default:
                error = .CB_headers_complete
                return RETURN(p - data) /* Error */
            }
          }

          if error != .OK {
            return RETURN(p - data)
          }

          if let len = gotoReexecute() { return len }
          // hh: TODO: I think this was a fallthrough, is that right?
          //     might be a reexecute issue
          assert(false, "reexecute fallthrough")

        case .s_headers_done:
          STRICT_CHECK(ch != LF);

          self.nread = 0

          let hasBody = self.flags.contains(.F_CHUNKED) ||
            (self.content_length > 0
              && self.content_length != Int.max /* ULLONG_MAX */)
          if (self.upgrade && (self.method == .CONNECT ||
                                  (self.flags.contains(.F_SKIPBODY))
                                   || !hasBody))
          {
            /* Exit, the rest of the message is in a different protocol. */
            UPDATE_STATE(NEW_MESSAGE);
            // CALLBACK_NOTIFY(message_complete);
            let len = CALLBACK_NOTIFY(onMessageComplete, &CURRENT_STATE,
                                      p, data)
            if let len = len { return len } // error
            return RETURN((p - data) + 1);
          }

          if self.flags.contains(.F_SKIPBODY) {
            UPDATE_STATE(NEW_MESSAGE);
            // CALLBACK_NOTIFY(message_complete);
            let len = CALLBACK_NOTIFY(onMessageComplete, &CURRENT_STATE,
                                      p, data)
            if let len = len { return len } // error
          } else if self.flags.contains(.F_CHUNKED) {
            /* chunked encoding - ignore Content-Length header */
            UPDATE_STATE(.s_chunk_size_start);
          } else {
            if self.content_length == 0 {
              /* Content-Length header given but zero: Content-Length: 0\r\n */
              UPDATE_STATE(NEW_MESSAGE);
              // CALLBACK_NOTIFY(message_complete);
              let len = CALLBACK_NOTIFY(onMessageComplete, &CURRENT_STATE,
                                        p, data)
              if let len = len { return len } // error
            } else if self.content_length != Int.max /* ULLONG_MAX */ {
              /* Content-Length header given and non-zero */
              UPDATE_STATE(.s_body_identity)
            } else {
              if (!messageNeedsEOF) {
                /* Assume content-length 0 - read the next */
                UPDATE_STATE(NEW_MESSAGE);
                // CALLBACK_NOTIFY(message_complete);
                let len = CALLBACK_NOTIFY(onMessageComplete, &CURRENT_STATE,
                                          p, data)
                if let len = len { return len } // error
              } else {
                /* Read body until EOF */
                UPDATE_STATE(.s_body_identity_eof)
              }
            }
          }

        case .s_body_identity:
          let to_read : Int /* uint64_t */ = min(self.content_length,
                                       ((data + len) - p));

          assert(self.content_length != 0
              && self.content_length != Int.max /* ULLONG_MAX */);

          /* The difference between advancing content_length and p is because
           * the latter will automaticaly advance on the next loop iteration.
           * Further, if content_length ends up at 0, we want to see the last
           * byte again for our message complete callback.
           */
          if body_mark == nil { body_mark = p } // MARK(body);

          self.content_length -= to_read;
          p += to_read - 1;

          if (self.content_length == 0) {
            UPDATE_STATE(.s_message_done);

            /* Mimic CALLBACK_DATA_NOADVANCE() but with one extra byte.
             *
             * The alternative to doing this is to wait for the next byte to
             * trigger the data callback, just as in every other case. The
             * problem with this is that this makes it difficult for the test
             * harness to distinguish between complete-on-EOF and
             * complete-on-length. It's not clear that this distinction is
             * important for applications, but let's keep it for now.
             */
            let rc = CALLBACK_DATA_(onBody, &body_mark, &CURRENT_STATE,
                                    p - body_mark + 1, p - data)
            if let rc = rc { return rc }
            
            if let len = gotoReexecute() { return len }
          }

        
        /* read until EOF */
        case .s_body_identity_eof:
          if body_mark == nil { body_mark = p } // MARK(body);
          p = data + len - 1;

        case .s_message_done:
          UPDATE_STATE(NEW_MESSAGE)
          
          // CALLBACK_NOTIFY(message_complete);
          let len = CALLBACK_NOTIFY(onMessageComplete, &CURRENT_STATE,
                                    p, data)
          if let len = len { return len } // error
          
          if self.upgrade {
            /* Exit, the rest of the message is in a different protocol. */
            return RETURN((p - data) + 1);
          }

        case .s_chunk_size_start:
          assert(self.nread == 1);
          assert(self.flags.contains(.F_CHUNKED))

          let unhex_val = unhex[Int(ch)]; // (unsigned char)
          guard unhex_val != -1 else {
            return gotoError(.INVALID_CHUNK_SIZE)
          }

          self.content_length = Int(unhex_val)
          UPDATE_STATE(.s_chunk_size);

        case .s_chunk_size:
          assert(self.flags.contains(.F_CHUNKED))

          if ch == CR { UPDATE_STATE(.s_chunk_size_almost_done); break; }

          let unhex_val = unhex[Int(ch)]

          if unhex_val == -1 {
            if ch == cSEMICOLON || ch == cSPACE {
              UPDATE_STATE(.s_chunk_parameters);
              break;
            }

            return gotoError(.INVALID_CHUNK_SIZE)
          }

          var t = self.content_length
          t *= 16
          t += Int(unhex_val)

          /* Overflow? Test against a conservative limit for simplicity. */
          if ((Int.max /*ULLONG_MAX*/ - 16) / 16 < self.content_length) {
            return gotoError(.INVALID_CONTENT_LENGTH)
          }
          
          self.content_length = t;

        case .s_chunk_parameters:
          assert(self.flags.contains(.F_CHUNKED))
          /* just ignore this shit. TODO check for overflow */
          if ch == CR {
            UPDATE_STATE(.s_chunk_size_almost_done);
          }

        case .s_chunk_size_almost_done:
          assert(self.flags.contains(.F_CHUNKED))
          STRICT_CHECK(ch != LF)

          self.nread = 0;

          if (self.content_length == 0) {
            self.flags.insert(.F_TRAILING)
            UPDATE_STATE(.s_header_field_start)
          } else {
            UPDATE_STATE(.s_chunk_data)
          }
          
          // CALLBACK_NOTIFY(chunk_header);
          let len = CALLBACK_NOTIFY(onChunkHeader, &CURRENT_STATE, p, data)
          if let len = len { return len } // error

        case .s_chunk_data:
          let to_read = min(self.content_length, ((data + len) - p))

          assert(self.flags.contains(.F_CHUNKED))
          assert(self.content_length != 0
              && self.content_length != Int.max /* ULLONG_MAX */)

          /* See the explanation in s_body_identity for why the content
           * length and data pointers are managed this way.
           */
          if body_mark == nil { body_mark = p } // MARK(body);
          self.content_length -= to_read;
          p += to_read - 1;

          if self.content_length == 0 {
            UPDATE_STATE(.s_chunk_data_almost_done);
          }
        
        case .s_chunk_data_almost_done:
          assert(self.flags.contains(.F_CHUNKED))
          assert(self.content_length == 0)
          STRICT_CHECK(ch != CR)
          UPDATE_STATE(.s_chunk_data_done);
          
          // CALLBACK_DATA(body);
          let rc = CALLBACK_DATA_(onBody, &body_mark, &CURRENT_STATE,
                                  p - body_mark + 1, p - data)
          if let rc = rc { return rc }

        case .s_chunk_data_done:
          assert(self.flags.contains(.F_CHUNKED))
          STRICT_CHECK(ch != LF);
          self.nread = 0
          UPDATE_STATE(.s_chunk_size_start);
          
          // CALLBACK_NOTIFY(chunk_complete);
          let len = CALLBACK_NOTIFY(onChunkComplete, &CURRENT_STATE, p, data)
          if let len = len { return len } // error

        default:
          assert(false) //  && "unhandled state");
          error = .INVALID_INTERNAL_STATE
          return gotoError()
      }
      
      return nil // no exception, goto next byte
    }
    
    assert(p == data)
    while p != (data + len) {
      ch = p.memory
      
      if CURRENT_STATE.isParsingHeader {
        if !COUNT_HEADER_SIZE(1) { return gotoError() }
      }
      
      // well, this recurses ... which is likely very bad
      if let len = gotoReexecute() { return len } // error?
    
      // FOR LOOP END
      p += 1
    }
    
    
    /* Run callbacks for any marks that we have leftover after we ran our of
     * bytes. There should be at most one of these set, so it's OK to invoke
     * them in series (unset marks will not result in callbacks).
     *
     * We use the NOADVANCE() variety of callbacks here because 'p' has already
     * overflowed 'data' and this allows us to correct for the off-by-one that
     * we'd otherwise have (since CALLBACK_DATA() is meant to be run with a 'p'
     * value that's in-bounds).
     */

    /* this seems to hang swiftc 2.2
     assert(((header_field_mark != nil ? 1 : 0) +
             (header_value_mark != nil ? 1 : 0) +
             (url_mark          != nil ? 1 : 0) +
             (body_mark         != nil ? 1 : 0) +
             (status_mark       != nil ? 1 : 0)) <= 1);
    */
     var rc = CALLBACK_DATA_NOADVANCE(onHeaderField, &header_field_mark,
                                      &CURRENT_STATE, p, data)
     if let rc1 = rc { return rc1 } // error
    
     rc = CALLBACK_DATA_NOADVANCE(onHeaderValue, &header_value_mark,
                                  &CURRENT_STATE, p, data)
     if let rc2 = rc { return rc2 } // error
    
     rc = CALLBACK_DATA_NOADVANCE(onURL, &url_mark, &CURRENT_STATE, p, data)
     if let rc3 = rc { return rc3 } // error
    
     rc = CALLBACK_DATA_NOADVANCE(onBody, &body_mark, &CURRENT_STATE, p, data)
     if let rc4 = rc { return rc4 } // error
    
     rc = CALLBACK_DATA_NOADVANCE(onStatus, &status_mark, &CURRENT_STATE,
                                  p, data)
     if let rc5 = rc { return rc5 } // error
 
     // regular return
     return RETURN(len)

    /* This goto is translated to gotoError()
     error:
       if error == .OK { error = .UNKNOWN }
       return RETURN(p - data);
    */
  }
 
  public func pause() {
    // TODO
  }
  public func resume() {
    // TODO
  }
  
  
  var isBodyFinal : Bool {
    // TODO
    return false
  }
  
  
  // MARK: - Implementation
  
  func STRICT_CHECK(condition: Bool) -> Bool {
    // the original has a 'goto error'
    if HTTP_PARSER_STRICT {
      if condition {
        error = .STRICT
        return false
      }
      return true
    }
    else {
      return true
    }
  }
  
  var startState : ParserState {
    return type == .HTTP_REQUEST ? .s_start_req : .s_start_res
  }
  
  var shouldKeepAlive : Bool = false // TODO: http_should_keep_alive
  
  var NEW_MESSAGE : ParserState {
    if HTTP_PARSER_STRICT {
      return shouldKeepAlive ? startState : .s_dead
    }
    else {
      return startState
    }
  }
  
  var messageNeedsEOF : Bool { // http_message_needs_eof()
    /* Does the parser need to see an EOF to find the end of the message? */
    if type == .HTTP_REQUEST {
      return false
    }
    
    /* See RFC 2616 section 4.4 */
    if status_code! / 100 == 1 || /* 1xx e.g. Continue */
       status_code! == 204 ||     /* No Content */
       status_code! == 304 ||     /* Not Modified */
       flags.contains(.F_SKIPBODY) {     /* response to a HEAD request */
      return false
    }
    
    if (flags.contains(.F_CHUNKED)
        || content_length != Int.max /* ULLONG_MAX */)
    {
      return false
    }
    
    return true
  }

  /* Don't allow the total size of the HTTP headers (including the status
   * line) to exceed HTTP_MAX_HEADER_SIZE.  This check is here to protect
   * embedders against denial-of-service attacks where the attacker feeds
   * us a never-ending header that the embedder keeps buffering.
   *
   * This check is arguably the responsibility of embedders but we're doing
   * it on the embedder's behalf because most won't bother and this way we
   * make the web a little safer.  HTTP_MAX_HEADER_SIZE is still far bigger
   * than any reasonable request or response so this should never affect
   * day-to-day operation.
   */
  func COUNT_HEADER_SIZE(V: Int) -> Bool {
    self.nread += V
    if self.nread > HTTP_MAX_HEADER_SIZE {
      error = .HEADER_OVERFLOW
      return false // original does 'goto error'
    }
    return true
  }
}


// HH: this is crap
private let PROXY_CONNECTION   = "proxy-connection".makeCString()
private let CONNECTION         = "connection".makeCString()
private let CONTENT_LENGTH     = "content-length".makeCString()
private let TRANSFER_ENCODING  = "transfer-encoding".makeCString()
private let UPGRADE            = "upgrade".makeCString()
private let CHUNKED            = "chunked".makeCString()
private let KEEP_ALIVE         = "keep-alive".makeCString()
private let CLOSE              = "close".makeCString()

private let lPROXY_CONNECTION  = 16
private let lCONNECTION        = 10
private let lCONTENT_LENGTH    = 14
private let lTRANSFER_ENCODING = 17 // strlen(TRANSFER_ENCODING)
private let lUPGRADE           =  7 // strlen(UPGRADE)
private let lCHUNKED           =  7 // strlen(CHUNKED)
private let lKEEP_ALIVE        = 10 // strlen(KEEP_ALIVE)
private let lCLOSE             =  5 // strlen(CLOSE)


/* Tokens as defined by rfc 2616. Also lowercases them.
 *        token       = 1*<any CHAR except CTLs or separators>
 *     separators     = "(" | ")" | "<" | ">" | "@"
 *                    | "," | ";" | ":" | "\" | <">
 *                    | "/" | "[" | "]" | "?" | "="
 *                    | "{" | "}" | SP | HT
 */
// Note: Swift has no neat Char=>Code conversion
let tokens : [ CChar ] /* [256] */ = [
/*   0 nul    1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  */
        0,       0,       0,       0,       0,       0,       0,       0,
/*   8 bs     9 ht    10 nl    11 vt    12 np    13 cr    14 so    15 si   */
        0,       0,       0,       0,       0,       0,       0,       0,
/*  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb */
        0,       0,       0,       0,       0,       0,       0,       0,
/*  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  */
        0,       0,       0,       0,       0,       0,       0,       0,
/*  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  '  */
        0,      33,      0,      35,     36,     37,     38,    39,
/*  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  */
        0,       0,      42,     43,      0,      45,     46,      0,
/*  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  */
       48,     49,     50,     51,52,53,54,55,
/*  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  */
       56,     57,      0,       0,       0,       0,       0,       0,
/*  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  */
        0,      65,66,67,68,69,70,71,
/*  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  */
       72,73,74,75,76,77,78,79,
/*  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  */
       80,81,82,83,84,85,86,87,
/*  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  */
       88,     89,     90,      0,       0,       0,      94,     95,
/*  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  */
       96,97,98,99,100,101,102,103,
/* 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  */
       104,105,106,107,108,109,110,111,
/* 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  */
       112,113,114,115,116,117,118,119,
/* 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del */
       120,     121,     122,      0,      124,      0,      126,       0 ]

let unhex : [ Int8 ] = [
  -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  , 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1
  ,-1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
]

let normal_url_char : [ UInt8 ] /* [32] */ = [
  /*   0 nul    1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  */
  0    |   0    |   0    |   0    |   0    |   0    |   0    |   0,
  /*   8 bs     9 ht */
  0    | (HTTP_PARSER_STRICT ? 0 : 2)
  /*   10 nl    11 vt    12 np    13 cr */
       |   0    |   0    | (HTTP_PARSER_STRICT ? 0 : 16)
  /*   13 cr    14 so    15 si   */
       |   0    |   0    |   0,
  /*  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb */
  0    |   0    |   0    |   0    |   0    |   0    |   0    |   0,
  /*  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  */
  0    |   0    |   0    |   0    |   0    |   0    |   0    |   0,
  /*  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  '  */
  0    |   2    |   4    |   0    |   16   |   32   |   64   |  128,
  /*  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /*  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /*  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |   0,
  /*  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /*  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /*  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /*  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /*  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /* 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /* 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
  /* 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del */
  1    |   2    |   4    |   8    |   16   |   32   |   64   |   0
]

enum ParserState : Int {
  case s_dead = 1 /* important that this is > 0 */
  
  case s_start_req_or_res
  case s_res_or_resp_H
  case s_start_res
  case s_res_H
  case s_res_HT
  case s_res_HTT
  case s_res_HTTP
  case s_res_first_http_major
  case s_res_http_major
  case s_res_first_http_minor
  case s_res_http_minor
  case s_res_first_status_code
  case s_res_status_code
  case s_res_status_start
  case s_res_status
  case s_res_line_almost_done
  
  case s_start_req
  
  case s_req_method
  case s_req_spaces_before_url
  case s_req_schema
  case s_req_schema_slash
  case s_req_schema_slash_slash
  case s_req_server_start
  case s_req_server
  case s_req_server_with_at
  case s_req_path
  case s_req_query_string_start
  case s_req_query_string
  case s_req_fragment_start
  case s_req_fragment
  case s_req_http_start
  case s_req_http_H
  case s_req_http_HT
  case s_req_http_HTT
  case s_req_http_HTTP
  case s_req_first_http_major
  case s_req_http_major
  case s_req_first_http_minor
  case s_req_http_minor
  case s_req_line_almost_done
  
  case s_header_field_start
  case s_header_field
  case s_header_value_discard_ws
  case s_header_value_discard_ws_almost_done
  case s_header_value_discard_lws
  case s_header_value_start
  case s_header_value
  case s_header_value_lws
  
  case s_header_almost_done
  
  case s_chunk_size_start
  case s_chunk_size
  case s_chunk_parameters
  case s_chunk_size_almost_done
  
  case s_headers_almost_done
  case s_headers_done
  
  /* Important: 's_headers_done' must be the last 'header' state. All
   * states beyond this must be 'body' states. It is used for overflow
   * checking. See the isParsingHeader property.
   */
  
  case s_chunk_data
  case s_chunk_data_almost_done
  case s_chunk_data_done
  
  case s_body_identity
  case s_body_identity_eof
  
  case s_message_done
  
  
  // PARSING_HEADER macro in orig
  var isParsingHeader : Bool {
    return self.rawValue <= ParserState.s_headers_done.rawValue
  }
}

enum ParserHeaderState : Int {
  case h_general = 0
  case h_C
  case h_CO
  case h_CON
  
  case h_matching_connection
  case h_matching_proxy_connection
  case h_matching_content_length
  case h_matching_transfer_encoding
  case h_matching_upgrade
  
  case h_connection
  case h_content_length
  case h_transfer_encoding
  case h_upgrade
  
  case h_matching_transfer_encoding_chunked
  case h_matching_connection_token_start
  case h_matching_connection_keep_alive
  case h_matching_connection_close
  case h_matching_connection_upgrade
  case h_matching_connection_token
  
  case h_transfer_encoding_chunked
  case h_connection_keep_alive
  case h_connection_close
  case h_connection_upgrade
}

enum ParserHTTPHostState : Int {
  case s_http_host_dead = 1
  case s_http_userinfo_start
  case s_http_userinfo
  case s_http_host_start
  case s_http_host_v6_start
  case s_http_host
  case s_http_host_v6
  case s_http_host_v6_end
  case s_http_host_v6_zone_start
  case s_http_host_v6_zone
  case s_http_host_port_start
  case s_http_host_port
}

/* Macros for character classes; depends on strict-mode  */

let CR : CChar = 13
let LF : CChar = 10

func LOWER(c: CChar) -> CChar { return c | 0x20 } // TODO: hm: UInt8 bitcast?

func IS_ALPHA(c: CChar) -> Bool {
  return (LOWER(c) >= 97 /* 'a' */ && LOWER(c) <= 122 /* 'z' */)
}

func IS_NUM(c: CChar) -> Bool {
  return ((c) >= 48 /* '0' */ && (c) <= 57 /* '9' */)
}

func IS_ALPHANUM(c: CChar) -> Bool { return IS_ALPHA(c) || IS_NUM(c) }

func IS_HEX(c: CChar) -> Bool {
  return (IS_NUM(c) || (LOWER(c) >= 97 /*'a'*/ && LOWER(c) <= 102 /*'f'*/))
}

func IS_MARK(c: CChar) -> Bool {
  return ((c) == 45 /* '-'  */ || (c) ==  95 /* '_' */ || (c) == 46 /* '.' */
       || (c) == 33 /* '!'  */ || (c) == 126 /* '~' */ || (c) == 42 /* '*' */
       || (c) == 92 /* '\'' */ || (c) ==  40 /* '(' */ || (c) == 41 /* ')' */)
}

func IS_USERINFO_CHAR(c: CChar) -> Bool {
  return (IS_ALPHANUM(c) || IS_MARK(c)
       || (c) == 37 /* '%' */ || (c) == 59 /* ';' */ || (c) == 58 /* ':' */
       || (c) == 38 /* '&' */ || (c) == 61 /* '=' */ || (c) == 43 /* '+' */
       || (c) == 36 /* '$' */ || (c) == 44 /* ',' */)
}

func STRICT_TOKEN(c: CChar) -> CChar {
  return tokens[Int(c)]
}

func TOKEN(c: CChar) -> CChar {
  if HTTP_PARSER_STRICT {
    return tokens[Int(c)]
  }
  else {
    return ((c == 32 /* ' ' */) ? 32 /* ' ' */ : tokens[Int(c)])
  }
}

func IS_URL_CHAR(c: CChar) -> Bool {
  fatalError("TODO: IS_URL_CHAR")
  /*
  if HTTP_PARSER_STRICT {
    return (BIT_AT(normal_url_char, (unsigned char)c))
  }
  else {
    return (BIT_AT(normal_url_char, (unsigned char)c) || ((c) & 0x80))
  }
  */
}

func IS_HOST_CHAR(c: CChar) -> Bool {
  if HTTP_PARSER_STRICT {
    return (IS_ALPHANUM(c) || (c) == 46 /* '.' */ || (c) == 45 /* '-' */)
  }
  else {
    return (IS_ALPHANUM(c) || (c) == 46 /* '.' */ || (c) == 45 /* '-' */
            || (c) == 95 /* '_' */)
  }
}
