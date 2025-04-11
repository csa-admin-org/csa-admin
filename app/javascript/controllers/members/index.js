// Import and register all your controllers from the importmap under controllers/*

import { application } from "controllers/members/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers/admin", application)
eagerLoadControllersFrom("controllers/members", application)
