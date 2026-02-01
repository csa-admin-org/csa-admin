# frozen_string_literal: true

ActiveAdmin.after_load do |app|
  module ActiveAdmin
    module AutoLinkHelper
      def auto_link(resource, content = display_name(resource), **html_options)
        kept = !resource.respond_to?(:kept?) || resource.kept?
        if kept && url = auto_url_for(resource)
          link_to content, url, html_options
        elsif resource.respond_to?(:discarded?) && resource.discarded?
          content_tag(:span, I18n.t("active_admin.deleted"), class: "attributes-table-empty-value")
        else
          content
        end
      end
    end
  end
end
