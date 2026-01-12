import { defineConfig } from 'vite'

export default defineConfig({
  root: 'src',
  clearScreen: false,
  server: {
    strictPort: true,
  },
  build: {
    target: 'esnext',
    minify: false,
    outDir: '../dist-frontend',
    emptyOutDir: true,
  },
})
