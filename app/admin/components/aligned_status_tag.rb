# frozen_string_literal: true

class AlignedStatusTag < ActiveAdmin::Component
  builder_method :aligned_status_tag

  def tag_name
    "span"
  end

  def build(status, options = {})
    super(nil)
    add_class "flex items-center justify-end"
    status_tag(status, options)
  end
end
