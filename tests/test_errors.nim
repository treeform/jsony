import jsony

try:
  discard fromJson("[123")
  assert false, "Should have raised"
except JsonyError:
  discard
