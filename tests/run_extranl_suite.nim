import os, osproc, sequtils, strutils

# https://github.com/nst/JSONTestSuite
# A comprehensive test suite for RFC 8259 compliant JSON parsers

let p = absolutePath("../JSONTestSuite/test_parsing/*")

for f in toSeq(os.walkFiles(p)):
  let
    what = f.split("/")[^1][0]
    cmd = "tests/run_test_jsony" & " " & f
    code = execCmd(cmd)
  var status =
    if code == 2:
      if what == 'y': "good "
      elif what == 'n': "fail "
      elif what == 'i': "good "
      else: "?"
    elif code == 1:
      if what == 'y': "fail "
      elif what == 'n': "good "
      elif what == 'i': "good "
      else: "?"
    else: "crash"
  echo "[", status, "] ", cmd
