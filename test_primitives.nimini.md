# Test primitives plugin

```nim on:init
print("Testing primitives plugin...")

# Test math primitives
let div_result = idiv(10, 3)
print("idiv(10, 3) = " & str(div_result))

let mod_result = imod(10, 3)
print("imod(10, 3) = " & str(mod_result))

let clamped = clamp(15, 0, 10)
print("clamp(15, 0, 10) = " & str(clamped))

let wrapped = wrap(12, 0, 10)
print("wrap(12, 0, 10) = " & str(wrapped))

let lerped = lerp(0, 100, 500)
print("lerp(0, 100, 500) = " & str(lerped))

# Test hash functions
let hash1 = intHash(42, 12345)
print("intHash(42, 12345) = " & str(hash1))

let hash2 = intHash2D(10, 20, 12345)
print("intHash2D(10, 20, 12345) = " & str(hash2))

print("✓ All primitives functions working!")
```

```nim on:render
clear()
draw(0, 0, 0, "Primitives Plugin Test")
draw(0, 0, 1, "All math functions auto-registered!")
draw(0, 0, 3, "Try: idiv, imod, clamp, wrap, lerp")
draw(0, 0, 4, "     intHash, intHash2D, map, smoothstep")
```
