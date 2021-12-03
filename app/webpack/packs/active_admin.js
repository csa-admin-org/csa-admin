const images = require.context("../images", true)
const imagePath = (name) => images(name, true)

require("trix")
require("@rails/actiontext")
require("turbolinks").start()

import { Application } from "@hotwired/stimulus"
import { definitionsFromContext } from "@hotwired/stimulus-webpack-helpers"
window.Stimulus = Application.start()
const context = require.context("../controllers", true, /\.js$/)
Stimulus.load(definitionsFromContext(context))

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
