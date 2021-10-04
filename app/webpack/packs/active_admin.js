const images = require.context("../images", true)
const imagePath = (name) => images(name, true)

require("trix")
require("@rails/actiontext")
require("turbolinks").start()

import "core-js/stable"
import "regenerator-runtime/runtime"

import "@activeadmin/activeadmin"

import "components/datepicker"
import "components/timepicker"
import "components/basket_content"
import "components/form"
import "components/ace_editor"
import "components/mail_preview"
import "components/tags"
import "components/emoji"

import "../stylesheets/active_admin"
