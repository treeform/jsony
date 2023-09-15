import jsony, random, unicode

randomize()

# ASCII
for i in 0 ..< 100_000:
  var s = ""
  for i in 0 ..< rand(0 .. 100):
    s.add char(rand(0 .. 127))

  if s.toJson().fromJson(string) != s:
    echo "some thing wrong!"
    echo repr(s)

# UNICODE
for i in 0 ..< 100_000:
  var s = ""
  for i in 0 ..< rand(0 .. 100):
    s.add $Rune(rand(0 .. 0x10FFFF))

  discard s.toJson().fromJson(string)

for i in 0 ..< 10_000:
  var s = ""
  for i in 0 ..< rand(0 .. 1_000):
    s.add cast[char](rand(0 .. 255))
  try:
    discard s.toJson().fromJson(string)
  except CatchableError:
    discard # Invalid UTF-8 etc is fine
