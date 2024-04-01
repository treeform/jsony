import jsony
type
  Conn = object
    id: int
  Foo = object
    a: int
    password: string
    b: float
    conn: Conn

proc skipHook(T: typedesc[Foo], key: static string): bool =
  key in ["password", "conn"]

let v = Foo(a:1, password: "12345", b:0.6, conn: Conn(id: 1))
doAssert v.toJson() ==
  """{"a":1,"b":0.6}"""

type
  Boo = ref object
    hoo: string
    x: seq[string]
    i: int
    b: bool

  Woo = object
    boo: Boo

proc skipHook(v: Boo, key: string): bool =
  result = v == nil

proc skipHook(v: string, key: string): bool =
  result = v.len == 0

proc skipHook(v: seq[string], key: string): bool =
  result = v.len == 0

let w = Woo(boo: Boo())
doAssert w.toJson() == 
  """{"boo":{"i":0,"b":false}}"""
let w2 = Woo()
doAssert w2.toJson() ==
  """{}"""
let b = Boo()
doAssert b.toJson() == 
  """{"i":0,"b":false}"""
