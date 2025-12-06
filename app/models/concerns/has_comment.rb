# frozen_string_literal: true

module HasComment
  extend ActiveSupport::Concern

  included do
    attr_accessor :comment
  end
end
