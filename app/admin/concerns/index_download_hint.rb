# frozen_string_literal: true

module IndexDownloadHint
  def index_download_hint(text)
    hint = para(text, class: "download-hint")
    paginated = ancestors.find { |node| node.class == ActiveAdmin::Views::PaginatedCollection }
    return unless paginated

    # Own row under the footer, so "Download:" stays where it was.
    # Bypass PaginatedCollection#add_child which redirects to @contents.
    Arbre::Element.instance_method(:add_child).bind_call(paginated, hint)
  end
end
