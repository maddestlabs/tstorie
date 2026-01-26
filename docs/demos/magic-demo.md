---
title: "Magic Demo - Zero Boilerplate Particles"
theme: "neotopia"
targetFPS: 60
---

# 🪄 Welcome to Magic!

This demo shows how **magic blocks** eliminate boilerplate code by compressing and parameterizing reusable snippets.

Each particle system below is created with a single line of code!

# Firefly Swarm

Watch the fireflies gently drift around the screen using the native particle system:

```magic
eJxtUctOwzAQvOcrrHBpEZSoEhLlShEgIVQ1hV5j4m2yku1EzqZS+QPEgWM+gyN3PiVfQppXkzYXWzszO971nLEXTrgFtuCG0JeQsDmoyLJcVLEEFtcwS3YJgWKiICeW5XmeRsUifYsayWpUT0UxsmP7gk0dZ9zCLtCD4VukXUU6kz65Ri1a5pSecxWjDhrF7KbHrlLznkrQPjQvH7XfKyQCs4iSSrCREadRgag1CgrZFZuOu+gjYBBSCQ/5uPgBg0YDJn2DZ9zAkuugGXS/6/XRsG8gI7/4qI7uclr+Sn0dzl7fXchNvZ/993ueZ1959p1nn3n2Yx+E+xU6+RQpdqNMY8EJWvFrWVZyAZL4ChWcNBnQAkzbtCzLOqpK/A9VJckS
```

# Simple Display

A basic demo showing value substitution:

```magic myValue="999"
eJxTVgjOzC3ISVUISS0u4eJKSEjIy8xVyM+zyszLLOEqSyxSKAbLhyXmlKYq2CpYWlpypSZn5CsoQfVl5mWWKBQl5ikqcSUkJCCbUJSal5JaxJVSlFiuYaCjYAjFMI1liTmlqVYKSgpqCsUlRRpI1mhqgo0CAEATMQg=
```

# Parameterized Particles

Now with custom parameters - change the name, count, and speed:

```magic name="stars" count="150" speed="15.0"
eJx9ksFKw0AQhu95ijVeWmlqKQhaRCgqVVAoSWuPZk2m7UB2EzYbpYY8gHjwmMfw6N1HyZO4iTZ20+ptZ/f7f2b+nX0ypoIykCDwGfyykugFEBune5ZFnOloaN+Ph/bw1hkQrsAO8cKEyw6JI1C8ZZ0ZxlpE4lUsgZEnlEsSrX3jrmG4rsuRkZAPkKM0oh/BtSpaZpqWxllmdkiaVu5Z1q4ZB+RI0EeUK43sdXsaM0PuN4Ft6oKyCPmiAZ4ca9AkEQ9JANyDRm/VyI3eLhlKNeQ4jDV4HoRUttQDm6Gv0jgk/fbm7RXgYimr6112jvqM//x2eOk+NzgHm/KF7tIvMzlqZHIHQeipeLdxqx5ZP+86apbnSyr0PMzPj4Mify3ytyJ/KfJ385cvR/5rCdTebC5PEvlUQq2cVqWm9SGQdIIMtrQCuA+i1tpVqS/Ct+Y
```

# How It Works

Each magic block above:
1. **Compresses** the preset markdown (3 code blocks → 1 line, ~70% smaller)
2. **Declares Parameters** via `<!-- MAGIC_PARAMS: ... -->` for safety
3. **Uses {{param}}** syntax to avoid accidental code conflicts
4. **Expands** at parse time with your custom parameter values
5. **Injects** the resulting code blocks into your document

**Zero boilerplate, pure magic!** 🪄

---

## Creating Your Own Magic

See [MAGIC.md](../MAGIC.md) for the complete guide.

Quick start:

1. Create a preset with `<!-- MAGIC_PARAMS: name, count -->` declaration
2. Use `{{name}}` and `{{count}}` placeholders in your code
3. Validate: `./tools/magic validate preset.md`
4. Compress: `./tools/magic pack preset.md`
5. Use in documents with `magic name="fireflies" count="30"`

1. **Write your reusable code** with `{param}` placeholders:
   ```markdown
   ```nim on:init
   var {name}_x = {startX}
   ```
   ```

2. **Compress it:**
   ```bash
   nim c -r tools/magic.nim pack my-preset.md
   ```

3. **Use it anywhere:**
   ```markdown
   ```magic name="myThing" startX="10"
   <compressed-base64-here>
   ```
   ```

4. **Share it!** Magic blocks are perfect for GitHub Gists.
