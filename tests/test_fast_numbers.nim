import jsony

for i in 0 .. 10000:
  var s = ""
  dumpHook(s, i)
  doAssert $i == s

for i in 0 .. 10000:
  var s = $i
  var idx = 0
  var v: int
  parseHook(s, idx, v)
  doAssert i == v
