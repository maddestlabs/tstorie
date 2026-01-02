import nimini

let code = """
proc outer() =
  proc inner() =
    var x = 1
"""

let tokens = tokenizeDsl(code)
echo "=== TOKENS ==="
for i, tok in tokens:
  echo i, ": ", tok.kind, " '", tok.lexeme, "' line=", tok.line
