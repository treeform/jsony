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
