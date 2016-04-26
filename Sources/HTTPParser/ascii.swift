//
//  ascii.swift
//  HTTPParser
//
//  Created by Helge Hess on 25/04/16.
//  Copyright © 2016 Always Right Institute. All rights reserved.
//

// Not in Swift: let c : CChar = 'A'

let cTAB       : CChar = 9  // \t
let cFORMFEED  : CChar = 12 // \f

let cSPACE     : CChar = 32 //
let cDASH      : CChar = 45 // -
let cSLASH     : CChar = 47 // /
let cCOLON     : CChar = 58 // :
let cSTAR      : CChar = 42 // *
let cAT        : CChar = 64 // @
let cHASH      : CChar = 35 // #
let cQM        : CChar = 63 // ?
let cLSB       : CChar = 91 // [
let cRSB       : CChar = 93 // ]
let cDOT       : CChar = 46 // .
let cCOMMA     : CChar = 44 // ,
let cSEMICOLON : CChar = 59 // ;

let cA : CChar = 65 // A
let cB : CChar = 66
let cC : CChar = 67
let cD : CChar = 68
let cE : CChar = 69
let cF : CChar = 70
let cG : CChar = 71
let cH : CChar = 72
let cI : CChar = 73
let cJ : CChar = 74
let cK : CChar = 75
let cL : CChar = 76
let cM : CChar = 77
let cN : CChar = 78
let cO : CChar = 79
let cP : CChar = 80
let cQ : CChar = 81
let cR : CChar = 82
let cS : CChar = 83
let cT : CChar = 84
let cU : CChar = 85 // U

let cc : CChar =  99 // c
let ck : CChar = 107 // k
let cn : CChar = 110 // n
let co : CChar = 111 // o
let cp : CChar = 112 // p
let ct : CChar = 116 // t
let cu : CChar = 117 // u

let c0 : CChar = 48 // 0
let c1 : CChar = 49
let c2 : CChar = 50
let c3 : CChar = 51
let c4 : CChar = 52
let c5 : CChar = 53
let c6 : CChar = 54
let c7 : CChar = 55
let c8 : CChar = 56
let c9 : CChar = 57 // 9


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
  // TODO: I don't get that normal_url_char map yet.
  return c != CR && c != LF && c > 32
  // fatalError("TODO: IS_URL_CHAR")
  /*
   #define BIT_AT(a, i) \
       (!!((unsigned int) (a)[(unsigned int) (i) >> 3] & \
       (1 << ((unsigned int) (i) & 7))))
   #define BIT_AT(a, i) (!!(a[i >> 3] & (1 << (i & 7))))
   
   let normal_url_char : [ UInt8 ] /* [32] */ = [ .. ]
   
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
