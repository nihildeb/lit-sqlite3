require('tap')(function(test)
  test('sqlite ffi loads', function()
    local ffi = require('ffi')
    local sql = require('sqlite3')
    assert(sql ~= nil)
    assert(type(sql) == "table", type(sql).." sql type, expected table")
  end)
end)

