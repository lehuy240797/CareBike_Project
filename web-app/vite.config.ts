import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
<<<<<<< HEAD
  plugins: [
    tailwindcss(),
    react()
  ],
=======
  plugins: [react(), tailwindcss()],
>>>>>>> 492036b821510e5bc8b94cc4f674d63891445bc7
})
