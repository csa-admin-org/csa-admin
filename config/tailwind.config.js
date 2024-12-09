import { execSync } from 'child_process'

const defaultTheme = require('tailwindcss/defaultTheme')

const activeAdminPath = execSync('bundle show activeadmin', { encoding: 'utf-8' }).trim()
const activeAdminPlugin = require(`${activeAdminPath}/plugin`)

export default {
  content: [
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{arb,erb,slim,html,rb}',
    './app/admin/**/*.{arb,erb,slim,html,rb}',
    './app/assets/**/*.css',
    `./vendor/javascript/flowbite.js`,
    './config/initializers/active_admin.rb',
    `${activeAdminPath}/vendor/javascript/flowbite.js`,
    `${activeAdminPath}/plugin.js`,
    `${activeAdminPath}/app/views/**/*.{arb,erb,html,rb}`
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['system-ui', 'Inter var', ...defaultTheme.fontFamily.sans],
      }
    }
  },
  darkMode: "class",
  plugins: [
    require('@tailwindcss/forms'),
    activeAdminPlugin
  ]
}
