local ffi = require "ffi"
local bit = require "bit"

local lib = require('ffi-loader')(module.dir, "sqlite3.h")

local sqlite3 = ffi.load("sqlite3")
local new_db_ptr = ffi.typeof("sqlite3*[1]")
local new_stmt_ptr = ffi.typeof("sqlite3_stmt*[1]")
--local new_exec_ptr = ffi.typeof("int (*)(void*,int,char**,char**)")
local new_blob_ptr = ffi.typeof("sqlite3_blob*[1]")
local new_bytearr = ffi.typeof("uint8_t[?]")
local sqlite3_transient = ffi.cast("void*",-1)

local value_handlers = {
  [sqlite3.SQLITE_INTEGER] = function(stmt, n)
    return sqlite3.sqlite3_column_int(stmt, n)
  end,
  [sqlite3.SQLITE_FLOAT] = function(stmt, n)
    return sqlite3.sqlite3_column_double(stmt, n)
  end,
  [sqlite3.SQLITE_TEXT] = function(stmt, n)
    -- off by one bug. seemed to be compensating for the +1 on the other side in bind
    -- return ffi.string(sqlite3.sqlite3_column_text(stmt,n), sqlite3.sqlite3_column_bytes(stmt,n)-1)
    return ffi.string(sqlite3.sqlite3_column_text(stmt,n), sqlite3.sqlite3_column_bytes(stmt,n))
  end,
  [sqlite3.SQLITE_BLOB] = function(stmt, n)
    return sqlite3.sqlite3_column_blob(stmt,n), sqlite3.sqlite3_column_bytes(stmt,n)
  end,
  [sqlite3.SQLITE_NULL] = function() return nil end
}

-- the main obj we will be returning as the module
local _sql = {}
_sql.DEBUG = false

local sqlite_db = {}

sqlite_db.__index = sqlite_db

function sqlite_db:__call(...)
	return self:exec(...)
end


local sqlite_stmt = {}

function sqlite_stmt:__index(k)
  if type(k) == "number" then
    return sqlite_stmt.get_value(self, k)
  else
    return sqlite_stmt[k]
  end
end

function sqlite_stmt:__newindex(...)
  sqlite_stmt.bind(self,...)
end

function sqlite_stmt:__call()
  return self:step()
end

local sqlite_blob = {}
sqlite_blob.__index = sqlite_blob


-- Enums

_sql.OK = sqlite3.SQLITE_OK
_sql.ERROR = sqlite3.SQLITE_ERROR
_sql.INTERNAL = sqlite3.SQLITE_INTERNAL
_sql.PERM = sqlite3.SQLITE_PERM
_sql.ABORT = sqlite3.SQLITE_ABORT
_sql.BUSY = sqlite3.SQLITE_BUSY
_sql.LOCKED = sqlite3.SQLITE_LOCKED
_sql.NOMEM = sqlite3.SQLITE_NOMEM
_sql.READONLY = sqlite3.SQLITE_READONLY
_sql.INTERRUPT = sqlite3.SQLITE_INTERRUPT
_sql.IOERR = sqlite3.SQLITE_IOERR
_sql.CORRUPT = sqlite3.SQLITE_CORRUPT
_sql.NOTFOUND = sqlite3.SQLITE_NOTFOUND
_sql.FULL = sqlite3.SQLITE_FULL
_sql.CANTOPEN = sqlite3.SQLITE_CANTOPEN
_sql.PROTOCOL = sqlite3.SQLITE_PROTOCOL
_sql.EMPTY = sqlite3.SQLITE_EMPTY
_sql.SCHEMA = sqlite3.SQLITE_SCHEMA
_sql.TOOBIG = sqlite3.SQLITE_TOOBIG
_sql.CONSTRAINT = sqlite3.SQLITE_CONSTRAINT
_sql.MISMATCH = sqlite3.SQLITE_MISMATCH
_sql.MISUSE = sqlite3.SQLITE_MISUSE
_sql.NOLFS = sqlite3.SQLITE_NOLFS
_sql.FORMAT = sqlite3.SQLITE_FORMAT
_sql.NOTADB = sqlite3.SQLITE_NOTADB
_sql.RANGE = sqlite3.SQLITE_RANGE
_sql.ROW = sqlite3.SQLITE_ROW
_sql.DONE = sqlite3.SQLITE_DONE
_sql.INTEGER = sqlite3.SQLITE_INTEGER
_sql.FLOAT = sqlite3.SQLITE_FLOAT
_sql.TEXT = sqlite3.SQLITE_TEXT
_sql.BLOB = sqlite3.SQLITE_BLOB
_sql.NULL = sqlite3.SQLITE_NULL


-- Library methods

local modes = {
	read = sqlite3.SQLITE_OPEN_READONLY,
	write = sqlite3.SQLITE_OPEN_READWRITE,
	create = bit.bor(sqlite3.SQLITE_OPEN_READWRITE, sqlite3.SQLITE_OPEN_CREATE)
}

function _sql.open(filename, mode)
  local sdb = new_db_ptr()

  local err = sqlite3.sqlite3_open_v2(
      filename,
      sdb,
      modes[mode or "create"] or error("unknown mode: "..tostring(mode),2),
      nil)

  local db = sdb[0]
  if err ~= sqlite3.SQLITE_OK then
    return nil, ffi.string(sqlite3.sqlite3_errmsg(db)), sqlite3.sqlite3_errcode(db)
  end

  return setmetatable({ db = db, stmts = {}, blobs = {}, }, sqlite_db)
end

function _sql.open_memory()
  return _sql.open(":memory:")
end

function _sql.complete(str)
  local r = sqlite3.sqlite3_complete(str)
  if r == sqlite3.SQLITE_NOMEM then error("out of memory",2) end
  return r ~= 0 and true or false
end

function _sql.version()
  return ffi.string(sqlite3.sqlite3_version)
end

-- database methods

function sqlite_db:changes()
  return sqlite3.sqlite3_changes(self.db)
end

function sqlite_db:close()
  local r = sqlite3.sqlite3_close(self.db)
  if r == sqlite3.SQLITE_OK then
    self.db = nil
  else
    self:check(r)
  end
end

function sqlite_db:errcode()
  return sqlite3.sqlite3_extended_errcode(self.db)
end
sqlite_db.error_code = sqlite_db.errcode

function sqlite_db:errmsg()
  return ffi.string(sqlite3.sqlite3_errmsg(self.db))
end
sqlite_db.error_message = sqlite_db.errmsg

function sqlite_db:exec(sql, func)
  local stmt = self:prepare(sql)
  while stmt:step() do
    if func ~= nil and type(func) == 'function' then
      func(stmt:get_values())
    end
  end
  stmt:finalize()
end

function sqlite_db:interrupt()
  sqlite3.sqlite3_interrupt(self.db)
end

function sqlite_db:isopen() return self.db and true or false end

function sqlite_db:last_insert_rowid()
  return tonumber(sqlite3.sqlite3_last_insert_rowid(self.db))
end

function sqlite_db:prepare(sql)
  local stmtptr = new_stmt_ptr()
  self:check(sqlite3.sqlite3_prepare_v2(self.db, sql, #sql+1, stmtptr, nil))
  local stmt = setmetatable(
  {
    stmt=stmtptr[0],
    db=self,
    trace=_sql.DEBUG and debug.traceback() or nil
  },sqlite_stmt)
  self.stmts[stmt] = stmt
  return stmt
end

function sqlite_db:get_autocommit()
  return sqlite3.sqlite3_get_autocommit(self.db) ~= 0
end

function sqlite_db:dump_unfinalized_statements()
  for _,stmt in pairs(self.stmts) do
    print(tostring(stmt))
    if stmt.trace then
      print("defined at: "..stmt.trace)
    end
  end
end

function sqlite_db:dump_unclosed_blobs()
  for _,blob in pairs(self.blobs) do
    print(tostring(blob))
    if blob.trace then
      print("defined at: "..blob.trace)
    end
  end
end




-- statement methods

function sqlite_stmt:bind(n, value, bloblen)
  --p('bind:',type(value))
  --p(n,':',value,':',bloblen)
  local t = type(value)
  if t == "string" then
    -- off by one bug compensating for the -1 in text value_handler
    --self.db:check(sqlite3.sqlite3_bind_text(self.stmt, n, value, #value+1, sqlite3_transient))
    self.db:check(sqlite3.sqlite3_bind_text(self.stmt, n, value, #value, sqlite3_transient))
  elseif t == "number" then
    self.db:check(sqlite3.sqlite3_bind_double(self.stmt, n, value))
  elseif t == "boolean" then
    self.db:check(sqlite3.sqlite3_bind_int(self.stmt, n, value))
  elseif t == "nil" then
    self.db:check(sqlite3.sqlite3_bind_null(self.stmt, n))
  elseif t == "cdata" then
    if ffi.istype("int64_t", value) then
      self.db:check(sqlite3.sqlite3_bind_int64(self.stmt, n, value))
    else
      self.db:check(sqlite3.sqlite3_bind_blob(self.stmt, n, value, bloblen, sqlite3_transient))
    end
  else
    error("invalid bind type: "..t,2)
  end
end

function sqlite_stmt:bind_values(...)
  local l=select("#",...)
  for i=1,l do
    self:bind(i,select(i,...))
  end
end

function sqlite_stmt:columns()
  return sqlite3.sqlite3_column_count(self.stmt)
end

function sqlite_stmt:finalize()
  local r = sqlite3.sqlite3_finalize(self.stmt)
  if r == sqlite3.SQLITE_OK then
    self.stmt = nil
    self.db.stmts[self] = nil
  else
    self.db:check(r)
  end
end

function sqlite_stmt:get_name(n)
  return ffi.string(sqlite3.sqlite3_column_name(self.stmt, n))
end

function sqlite_stmt:get_named_types()
  local tbl = {}
  for i=0,sqlite3.sqlite3_column_count(self.stmt)-1 do
    tbl[ffi.string(sqlite3.sqlite3_column_name(self.stmt, n))] = ffi.string(sqlite3.sqlite3_column_decltype(self.stmt, n))
  end
  return tbl
end

-- TODO: stmt:get_named_values
-- TODO: stmt:get_names
-- TODO: stmt:get_unames
-- TODO: stmt:get_utypes
-- TODO: stmt:get_uvalues

function sqlite_stmt:get_value(n)
  return value_handlers[sqlite3.sqlite3_column_type(self.stmt,n)](self.stmt,n)
end

function sqlite_stmt:get_values()
  local tbl = {}
  for i=0,sqlite3.sqlite3_column_count(self.stmt)-1 do
    tbl[i+1] = self:get_value(i)
  end
  return tbl
end

function sqlite_stmt:get_values_unpacked(n)
  n = n or 0
  if n < sqlite3.sqlite3_column_count(self.stmt) then
    return self:get_value(n), self:get_values_unpacked(n+1)
  end
end

function sqlite_stmt:isopen() return self.stmt and true or false end


function sqlite_stmt:reset()
  self.db:check(sqlite3.sqlite3_reset(self.stmt))
end

function sqlite_stmt:rows()
  return function()
    if self:step() then
      return self:get_values()
    else
      return nil
    end
  end
end

function sqlite_stmt:rows_unpacked()
  return function()
    if self:step() then
      return self:get_values_unpacked()
    else
      return nil
    end
  end
end

function sqlite_stmt:step()
  local ret = sqlite3.sqlite3_step(self.stmt)
  if ret == sqlite3.SQLITE_ROW then
    return true
  elseif ret == sqlite3.SQLITE_DONE then
    return false
  else
    error(self.db:errmsg(),0)
  end
end

function sqlite_db:total_changes()
  return sqlite3.sqlite3_total_changes(self.db)
end

function sqlite_db:check(ret)
  if ret ~= sqlite3.SQLITE_OK then error(self:errmsg(),0) end
  return ret
end







return _sql
