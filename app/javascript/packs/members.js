/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

import 'babel-polyfill'

import Turbolinks from 'turbolinks';
Turbolinks.start();

import Rails from 'rails-ujs';
Rails.start();

import 'normalize.css';
import 'scss/members';

import 'components/menu';
import 'components/calendar';
import 'components/member_new_form';
