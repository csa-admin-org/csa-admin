ActiveAdmin.before_load do |app|
  require "active_admin/filter_saver"
  ActiveAdmin::BaseController.send :include, ActiveAdmin::FilterSaver
end
