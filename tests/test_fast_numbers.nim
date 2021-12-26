import jsony

# doAssertRaises JsonError:
#   var
#     s = ""
#     i = 0
#     n: uint64
#   parseHook(s, i, n)

# for i in 0 .. 10000:
#   var s = ""
#   dumpHook(s, i)
#   doAssert $i == s

# for i in 0 .. 10000:
#   var s = $i
#   var idx = 0
#   var v: int
#   parseHook(s, idx, v)
#   doAssert i == v
