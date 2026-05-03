import "components/appsignal"
import "@hotwired/turbo-rails"
import "admin/trix"
import "controllers/admin"

import Rails from "@rails/ujs"
import "active_admin/features/batch_actions"

import "active_admin/features/has_many"
import "active_admin/features/filters"
import "active_admin/features/main_menu"
import "active_admin/features/per_page"

Rails.start()
