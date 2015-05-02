return {
  name = "nihildeb/sqlite3",
  version = "0.0.1",
  homepage = "https://github.com/nihildeb/lit-sqlite3",
  dependencies = {
    "creationix/ffi-loader@1.0.0"
  },
  files = {
    "*.lua",
    "*.h",
    "!sqlite3",
    "!test-app",
    "$OS-$ARCH/*",
  }
}
