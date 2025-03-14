# frozen_string_literal: true

class Columns < ActiveAdmin::Component
  builder_method :columns

  def build(*args)
    super
    add_class "flex flex-col md:flex-row gap-5"
  end

  def column(*args, &block)
    options = args.extract_options!
    insert_tag Arbre::HTML::Div, **options, class: "md:first:w-3/5 md:last:w-2/5 space-y-5!", &block
  end
end
