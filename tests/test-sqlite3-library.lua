local eq = require('./utils').eq

require('tap')(function(test)

  test('has a version', function()
    local sql = require('sqlite3')
    assert(eq('3.8.9', sql.version()))
  end)

  test('opens a memory db', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(mem ~= nil)
    assert(mem.db ~= nil)
    assert(eq('cdata', type(mem.db)))
  end)

  test('opens a file db', function()
    local fs = require('fs')
    local test_db_name = 'test.db'
    assert(eq(false, fs.existsSync(test_db_name)))

    local sql = require('sqlite3')
    local db = sql.open(test_db_name)
    assert(db ~= nil)
    assert(db.db ~= nil)
    assert(eq('cdata', type(db.db)))
    assert(eq(true, fs.existsSync(test_db_name)))
    os.remove(test_db_name)
  end)

  test('complete() recognizes a complete stmt', function()
    local sql = require('sqlite3')
    local good_stmt = "select date('now');"
    local bad_stmt =  "select date('now')"
    assert(eq(true, sql.complete(good_stmt)))
    assert(eq(false, sql.complete(bad_stmt)))
  end)

end)


