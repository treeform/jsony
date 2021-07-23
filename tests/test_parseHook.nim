import jsony, strutils, tables

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

when not defined(js):
  import times
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
