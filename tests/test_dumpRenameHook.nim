import jsony

type
  Foo = object
    aVal: int
    bVal: bool

proc dumpRenameHook(v: typedesc[Foo], fieldName: var string) =
  if fieldName == "aVal":
    fieldName = "a_val"

let v = Foo(aVal:2, bVal: true)
let ser = v.toJson()
echo $ser
doAssert ser ==
  """{"a_val":2,"bVal":true}"""
