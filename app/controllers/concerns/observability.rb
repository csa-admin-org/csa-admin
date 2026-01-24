# frozen_string_literal: true

module Observability
  extend ActiveSupport::Concern

  private

  def set_observability_context(**tags)
    Appsignal.add_tags(**tags)
    Rails.error.set_context(**tags)
    Rails.event.set_context(**tags)
  end
end
