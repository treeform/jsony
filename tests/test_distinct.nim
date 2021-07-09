import jsony

type
  Timestamp* = distinct float64 ## Always seconds since 1970 UTC.

proc `$`*(a: Timestamp): string =
  ## Display a timestamps as a float64.
  $float64(a)

proc `==`*(a, b: Timestamp): bool =
  ## Compare timestamps.
  float64(a) == float64(b)

var t = Timestamp(123.123)

doAssert t.toJson() == "123.123"
doAssert "1234.123".fromJson(Timestamp) == Timestamp(1234.123)
doAssert t.toJson().fromJson(Timestamp) == t
