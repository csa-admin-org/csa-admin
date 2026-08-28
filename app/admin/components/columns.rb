# frozen_string_literal: true

class Columns < ActiveAdmin::Component
  builder_method :columns

  def build(*args)
    super
    add_class "admin-columns"
  end

  def column(*args, &block)
    options = args.extract_options!
    insert_tag Arbre::HTML::Div, **options, class: "admin-column", &block
  end
end
