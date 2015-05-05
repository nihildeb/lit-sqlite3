local eq = require('./utils').eq

require('tap')(function(test)

  test('changes', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(eq(0, mem:changes()))
  end)

  test('closes', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(eq('cdata', type(mem.db)))
    assert(eq(nil, mem:close()))
    assert(eq(nil, mem.db))
  end)

  test('errcode support', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(eq(0, mem:errcode()))
    assert(eq(0, mem:error_code()))
    assert(eq(nil, mem:close()))
    assert(eq(nil, mem.db))
  end)

  test('error_message support', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(eq('not an error', mem:errmsg()))
    assert(eq('not an error', mem:error_message()))
    assert(eq(nil, mem:close()))
    assert(eq(nil, mem.db))
  end)

  test('exec with callback', function()
    local ffi = require "ffi"
    local sql = require('sqlite3')
    local mem = sql.open_memory()

    local stmt = "select date('now') as mydate;"
    mem:exec(stmt, function(values)
      for i,v in ipairs(values) do
        assert(eq(os.date("%Y-%m-%d"), v))
      end
    end)
    assert(eq(nil, mem:close()))
    assert(eq(nil, mem.db))
  end)

  test('exec no callback', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    local stmt = "select date('now') as mydate;"
    mem:exec(stmt)
    assert(eq(nil, mem:close()))
    assert(eq(nil, mem.db))
  end)

  test('isopen', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(eq(true, mem:isopen()))
    assert(eq(nil, mem:close()))
    assert(eq(false, mem:isopen()))
    assert(eq(nil, mem.db))
  end)

  test('last_insert_rowid', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(eq(0, mem:last_insert_rowid()))
    assert(eq(nil, mem:close()))
    assert(eq(nil, mem.db))
  end)

  test('prepare and finalize', function()
    local ffi = require('ffi')
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(eq(0, tablelength(mem.stmts)))
    local p = mem:prepare("select date('now');")
    assert(eq(1, tablelength(mem.stmts)))
    p:finalize()
    assert(eq(0, tablelength(mem.stmts)))
    assert(eq(nil, mem:close()))
    assert(eq(nil, mem.db))
  end)

  test('total_changes', function()
    -- TODO: test this in real create table test
    local sql = require('sqlite3')
    local mem = sql.open_memory()
  end)

  test('get_autocommit', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    assert(eq(true, mem:get_autocommit()))
    local stmt = "BEGIN"
    mem:exec(stmt)
    assert(eq(false, mem:get_autocommit()))
    local stmt = "COMMIT"
    mem:exec(stmt)
    assert(eq(true, mem:get_autocommit()))
    assert(eq(nil, mem:close()))
    assert(eq(nil, mem.db))
  end)

  test('constraits on exec and total_changes', function()
    local sql = require('sqlite3')
    local mem = sql.open_memory()
    local schema = [[
      create table kv (
        key text primary key not null,
        value text not null
      );
    ]]
    local insert = function()
      mem:exec("insert into kv values('1', 'one');")
    end
    assert(eq(nil, mem:exec("drop table if exists kv;")))
    assert(eq(nil, mem:exec(schema)))
    assert(eq(0, mem:total_changes()))
    assert(eq(true, pcall(insert))) -- first insert success
    assert(eq(1, mem:total_changes()))
    assert(eq(false, pcall(insert)))-- second is unique constraint failure
    assert(eq(1, mem:total_changes()))
  end)

  test('prepared stmt with binds', function()
    local sql = require('sqlite3')
    local db = sql.open_memory()
    local schema = [[
      create table kv (
        key text primary key not null,
        value text not null
      );
    ]]

    local insert = function()
      db:exec("insert into kv values('1', 'one again');")
    end

    assert(eq(nil, db:exec("drop table if exists kv;")))
    assert(eq(nil, db:exec(schema)))
    local stmt = db:prepare("insert into kv values(?,?);")

    --local ffi = require('ffi')
    --stmt:bind_values(ffi.string('1'),ffi.string('one'))
    stmt:bind_values('1', 'one')
    assert(eq(false, stmt:step()))
    stmt:reset()
    stmt:bind_values('2','two')
    assert(eq(false, stmt:step()))
    stmt:reset()
    stmt:bind_values('3','tre')
    assert(eq(false, stmt:step()))
    stmt:finalize()
    assert(eq(3, db:total_changes()))

    assert(eq(false, pcall(insert))) -- second is unique constraint failure
    assert(eq(3, db:total_changes()))
  end)

  test('multi-statement exec without params', function()
    local sql = require('sqlite3')
    local db = sql.open_memory()
    local schema = [[
      create table kv (
        key text primary key not null,
        value text not null
      );
    ]]

    assert(eq(nil, db:exec("drop table if exists kv;")))
    assert(eq(nil, db:exec(schema)))
    assert(eq(nil, db:exec("insert into kv values('1','one');")))
    assert(eq(nil, db:exec("insert into kv values('2','two');")))
    assert(eq(nil, db:exec("insert into kv values('3','tre');")))

    stmt = db:prepare("select * from kv;")
    while stmt:step() do
      local t = stmt:get_values()

      if t[1] == '1' then assert(eq(t[2], 'one'))
      elseif t[1] == '2' then assert(eq(t[2], 'two'))
      elseif t[1] == '3' then assert(eq(t[2], 'tre'))
      else
        assert(eq('bad key:', t[1]))
      end
    end
  end)

  test('multi-statement exec with params', function()
    local sql = require('sqlite3')
    local db = sql.open_memory()
    local schema = [[
      create table kv (
        key text primary key not null,
        value text not null
      );
    ]]

    assert(eq(nil, db:exec("drop table if exists kv;")))
    assert(eq(nil, db:exec(schema)))
    local stmt = db:prepare("insert into kv values(?,?);")

    stmt:bind_values('1','one')
    assert(eq(false, stmt:step()))
    stmt:reset()
    stmt:bind_values('2','two')
    assert(eq(false, stmt:step()))
    stmt:reset()
    stmt:bind_values('3','tre')
    assert(eq(false, stmt:step()))
    stmt:finalize()

    stmt = db:prepare("select * from kv;")
    while stmt:step() do
      local t = stmt:get_values()
      if t[1] == '1' then assert(eq(t[2], 'one'))
      elseif t[1] == '2' then assert(eq(t[2], 'two'))
      elseif t[1] == '3' then assert(eq(t[2], 'tre'))
      else
        assert(eq('bad key:', t[1]))
      end
    end
  end)

  test('empty string', function()
    local sql = require('sqlite3')
    local db = sql.open_memory()
    local schema = [[
      create table kv (
        key text primary key not null,
        value text not null
      );
    ]]

    assert(eq(nil, db:exec("drop table if exists kv;")))
    assert(eq(nil, db:exec(schema)))
    local stmt = db:prepare("insert into kv values(?,?);")

    stmt:bind_values('1','')
    assert(eq(false, stmt:step()))
    stmt:reset()
    stmt:bind_values('2','two')
    assert(eq(false, stmt:step()))
    stmt:reset()
    stmt:bind_values('3','')
    assert(eq(false, stmt:step()))
    stmt:finalize()

    stmt = db:prepare("select * from kv;")
    while stmt:step() do
      local t = stmt:get_values()
      if t[1] == '1' then assert(eq(t[2], ''))
      elseif t[1] == '2' then assert(eq(t[2], 'two'))
      elseif t[1] == '3' then assert(eq(t[2], ''))
      else
        assert(eq('bad key:', t[1]))
      end
    end
  end)

  test('all sqlite types', function()
    local sql = require('sqlite3')
    local db = sql.open_memory()
    local schema = [[
      create table ttype (
        cint int,
        cfloat float,
        ctext text,
        cblob blob,
        cnull null
      );
    ]]

    assert(eq(nil, db:exec("drop table if exists ttype;")))
    assert(eq(nil, db:exec(schema)))

    local stmt = db:prepare("insert into ttype values(?,?,?,?,?);")
    local bin = string.dump(function() return 'hello whirld\n\0' end)
    stmt:bind_values(1, 2.0, 'hiya', bin, nil)
    stmt:step()
    stmt:finalize()

    stmt = db:prepare("select * from ttype;")
    while stmt:step() do
      local t = stmt:get_values()
      assert(eq('table', type(t)))
      assert(eq(4, #t))
      assert(eq(1, t[1]))
      assert(eq(2.0, t[2]))
      assert(eq('hiya', t[3]))
      assert(eq(bin, t[4]))
      assert(eq(#bin, #t[4]))
      -- null type not returned from query
    end
  end)

end)

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

