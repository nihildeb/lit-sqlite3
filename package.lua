return {
  name = "nihildeb/sqlite3",
  version = "0.1.0",
  homepage = "https://github.com/nihildeb/lit-sqlite3",
  dependencies = {
    "creationix/ffi-loader@1.0.0",
    "luvit/require@1.1.0",
    "luvit/pretty-print@1.0.1",
    "luvit/utils@1.0.0",
  },
  files = {
    "*.lua",
    "*.h",
    "!sqlite-src",
    "!build",
    "!test",
    "$OS-$ARCH/*",
  }
}
