import { execSync } from 'child_process'

const defaultTheme = require('tailwindcss/defaultTheme')
const activeAdminPath = execSync('bundle show activeadmin', { encoding: 'utf-8' }).trim()
const activeAdminPlugin = require(`${activeAdminPath}/plugin`)

export default {
  content: [
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*',
    `./vendor/javascript/flowbite.js`,
    `${activeAdminPath}/vendor/javascript/flowbite.js`,
    `${activeAdminPath}/plugin.js`,
    `${activeAdminPath}/app/views/**/*.{arb,erb,html,rb}`,
    './app/admin/**/*.{arb,erb,html,rb}',
    './app/assets/**/*.css',
    './config/initializers/active_admin.rb',
    './app/views/active_admin/**/*.{arb,erb,html,rb}',
    './app/views/admin/**/*.{arb,erb,html,rb}',
    './app/views/layouts/active_admin*.{erb,html}',
    './app/javascript/**/*.js'
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
    require(`${activeAdminPath}/plugin`)
  ]
}
