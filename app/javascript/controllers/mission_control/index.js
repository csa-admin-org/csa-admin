import { application } from "controllers/mission_control/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers/mission_control", application)
