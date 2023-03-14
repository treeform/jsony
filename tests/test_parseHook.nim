import json, jsony, strutils, tables, times

type Fraction = object
  numerator: int
  denominator: int

proc parseHook(s: string, i: var int, v: var Fraction) =
  ## Instead of looking for fraction object look for a string.
  var str: string
  parseHook(s, i, str)
  let arr = str.split("/")
  v = Fraction()
  v.numerator = parseInt(arr[0])
  v.denominator = parseInt(arr[1])

var frac = """ "1/3" """.fromJson(Fraction)
doAssert frac.numerator == 1
doAssert frac.denominator == 3

proc parseHook(s: string, i: var int, v: var DateTime) =
  var str: string
  parseHook(s, i, str)
  v = parse(str, "yyyy-MM-dd hh:mm:ss")

var dt = """ "2020-01-01 00:00:00" """.fromJson(DateTime)
doAssert dt.year == 2020

type Entry = object
  id: string
  count: int
  filled: int

let data = """{
  "1": {"count":12, "filled": 11},
  "2": {"count":66, "filled": 0},
  "3": {"count":99, "filled": 99}
}"""

proc parseHook(s: string, i: var int, v: var seq[Entry]) =
  var table: Table[string, Entry]
  parseHook(s, i, table)
  for k, entry in table.mpairs:
    entry.id = k
    v.add(entry)

let s = data.fromJson(seq[Entry])
doAssert type(s) is seq[Entry]
doAssert $s == """@[(id: "1", count: 12, filled: 11), (id: "2", count: 66, filled: 0), (id: "3", count: 99, filled: 99)]"""

type Entry2 = object
  id: int
  pre: int
  post: int
  kind: string

let data2 = """{
  "id": 3444,
  "changes": [1, 2, "hi"]
}"""

proc parseHook(s: string, i: var int, v: var Entry2) =
  var entry: JsonNode
  parseHook(s, i, entry)
  v = Entry2()
  v.id = entry["id"].getInt()
  v.pre = entry["changes"][0].getInt()
  v.post = entry["changes"][1].getInt()
  v.kind = entry["changes"][2].getStr()

let s2 = data2.fromJson(Entry2)
doAssert type(s2) is Entry2
doAssert $s2 == """(id: 3444, pre: 1, post: 2, kind: "hi")"""

# Non unique / double keys in json
# https://forum.nim-lang.org/t/8787
type Header = object
  key: string
  value: string
proc parseHook(s: string, i: var int, v: var seq[Header]) =
  eatChar(s, i, '{')
  while i < s.len:
    eatSpace(s, i)
    if i < s.len and s[i] == '}':
      break
    var key, value: string
    parseHook(s, i, key)
    eatChar(s, i, ':')
    parseHook(s, i, value)
    v.add(Header(key: key, value: value))
    eatSpace(s, i)
    if i < s.len and s[i] == ',':
      inc i
    else:
      break
  eatChar(s, i, '}')

let data3 = """{
  "Cache-Control": "private, max-age=0d",
  "Content-Encoding": "brd",
  "Set-Cookie": "name=valued",
  "Set-Cookie": "name=value; name2=value2; name3=value3d"
}"""

let headers = data3.fromJson(seq[Header])
doAssert headers[0].key == "Cache-Control"
doAssert headers[0].value == "private, max-age=0d"
doAssert headers[1].key == "Content-Encoding"
doAssert headers[1].value == "brd"
doAssert headers[2].key == "Set-Cookie"
doAssert headers[2].value == "name=valued"
doAssert headers[3].key == "Set-Cookie"
doAssert headers[3].value == "name=value; name2=value2; name3=value3d"
