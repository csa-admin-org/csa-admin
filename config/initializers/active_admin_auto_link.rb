# frozen_string_literal: true

ActiveAdmin.after_load do |app|
  module ActiveAdmin
    module ViewHelpers
      module AutoLinkHelper
        def auto_link(resource, content = display_name(resource))
          kept = !resource.respond_to?(:kept?) || resource.kept?
          if kept && url = auto_url_for(resource)
            link_to content, url
          else
            content
          end
        end
      end
    end
  end
end
