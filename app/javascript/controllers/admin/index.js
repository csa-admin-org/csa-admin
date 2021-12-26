// Import and register all your controllers from the importmap under controllers/*

import { application } from "controllers/admin/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers/admin", application)
