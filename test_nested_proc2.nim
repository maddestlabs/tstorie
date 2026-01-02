import nimini
import std/tables

let code = """
proc generateBSPDungeon(w: int, h: int, seed: int): seq =
  var rng = initRand(seed)
  
  var dungeonWidth = w
  var dungeonHeight = h
  
  proc splitAndCreateRooms(x: int, y: int, partW: int, partH: int, depth: int) =
    if depth <= 0:
      return
    
    if rng.rand(1) == 0:
      var minSplit = 2
      splitAndCreateRooms(x, y, partW, minSplit, depth - 1)
  
  splitAndCreateRooms(1, 1, w - 2, h - 2, 4)
  
  return newSeq(10)

var grid = generateBSPDungeon(79, 25, 12345)
"""

try:
  let tokens = tokenizeDsl(code)
  echo "Tokens: OK"
  let program = parseDsl(tokens)
  echo "Parse: OK"
except NiminiParseError as e:
  echo "Parse error at line ", e.line, ", col ", e.col, ": ", e.msg
except Exception as e:
  echo "Error: ", e.msg
  echo getCurrentExceptionMsg()
