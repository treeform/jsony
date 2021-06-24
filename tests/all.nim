# This is mainly used to test js
# nim js -r .\tests\all.nim
# nim cpp -r .\tests\all.nim

import test_arrays
import test_char
import test_enums
import test_errors
import test_fast_numbers
import test_json_in_json
import test_numbers
import test_objects
import test_options
import test_parseHook
import test_sets
import test_strings
import test_tables
import test_tojson
import test_tuples
import test_refs

echo "all tests pass"
