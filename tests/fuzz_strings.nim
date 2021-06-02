import random, jsony, unicode

randomize()

# ASCII
for i in 0 ..< 100_000:
  var s = ""
  for i in 0 ..< rand(0 .. 100):
    s.add char(rand(0 .. 128))

  if s.toJson().fromJson(string) != s:
    echo "some thing wrong!"
    echo repr(s)

# UNICODE
for i in 0 ..< 100_000:
  var s = ""
  for i in 0 ..< rand(0 .. 100):
    s.add $Rune(rand(0 .. 0x10FFFF))

  if s.toJson().fromJson(string) != s:
    echo "some thing wrong!"
    echo repr(s)
