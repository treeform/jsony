import jsony

proc dumpHook*(s: var string, v: object) =
  s.add '{'
  var i = 0
  # Normal objects.
  for k, e in v.fieldPairs:
    when compiles(e != nil):
      if e != nil:
        if i > 0:
          s.add ','
        s.dumpHook(k)
        s.dumpHook(e)
        inc i
    else:
      if i > 0:
        s.add ','
      s.dumpHook(k)
      s.dumpHook(e)
      inc i
  s.add '}'

type
  Foo = ref object
    count: int

  Bar = object
    id: string
    something: Foo

var
  foo1 = Bar(
    id: "123",
    something: Foo(count: 1)
  )
  foo2 = Bar(
    id: "456",
    something: nil
  )

doAssert foo1.toJson() == """{"id":"123","something":{"count":1}}"""
doAssert foo2.toJson() == """{"id":"456","something":null}"""
