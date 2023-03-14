# This is mainly used to test js
# nim js -r .\tests\all.nim
# nim cpp -r .\tests\all.nim

import test_arrays, test_char, test_enums, test_errors, test_fast_numbers,
    test_json_in_json, test_numbers, test_objects, test_options, test_parseHook,
    test_rawjson, test_refs, test_sets, test_skipHook, test_strings, test_tables, test_tojson, test_tuples
echo "all tests pass"