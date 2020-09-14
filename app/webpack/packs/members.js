// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/webpack and only use these pack files to reference
// that code so it'll be compiled.

const images = require.context('../images', true)
const imagePath = (name) => images(name, true)

require('@rails/ujs').start()
require('turbolinks').start()
// require("@rails/activestorage").start()
// require("channels")

import 'core-js/stable'
import 'regenerator-runtime/runtime'

import 'components/menu';
import 'components/calendar';
import 'components/member_new_form';
import 'components/group_buying';

import 'normalize.css';
import 'stylesheets/members.scss';
