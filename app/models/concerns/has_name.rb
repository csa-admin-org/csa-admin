# frozen_string_literal: true

module HasName
  extend ActiveSupport::Concern

  included do
    scope :order_by_name, ->(dir = "ASC") {
      order("unaccent(text_lower(#{table_name}.name)) #{dir}")
    }
    scope :reorder_by_name, ->(dir = "ASC") {
      unscope(:order).order_by_name(dir)
    }

    validates :name, presence: true
  end
end
