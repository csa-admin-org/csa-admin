const { environment } = require('@rails/webpacker')
const jquery = require('./plugins/jquery')
const magicImporter = require('node-sass-magic-importer');

module.exports = environment

environment.plugins.prepend('jquery', jquery)
environment.loaders.get('sass')
  .use
  .find(item => item.loader === 'sass-loader')
  .options
  .sassOptions = { importer: magicImporter() };
