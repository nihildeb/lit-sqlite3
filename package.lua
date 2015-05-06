return {
  name = "nihildeb/sqlite3",
  version = "1.0.0",
  homepage = "https://github.com/nihildeb/lit-sqlite3",
  dependencies = {
    "luvit/require@1.1.0",
    "luvit/pretty-print@1.0.1",
    "creationix/ffi-loader@1.0.0",
  },
  files = {
    "*.lua",
    "*.h",
    "!build",
    "$OS-$ARCH/*",
  }
}
