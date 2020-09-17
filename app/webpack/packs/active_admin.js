const images = require.context('../images', true)
const imagePath = (name) => images(name, true)

require('trix')
require('@rails/actiontext')
require('turbolinks').start()

import 'core-js/stable'
import 'regenerator-runtime/runtime'

import '@activeadmin/activeadmin';

import 'components/active_admin/datepicker';
import 'components/active_admin/timepicker';
import 'components/active_admin/basket_content';
import 'components/active_admin/form';

import '../stylesheets/active_admin';
