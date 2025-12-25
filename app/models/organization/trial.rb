# frozen_string_literal: true

module Organization::Trial
  extend ActiveSupport::Concern

  included do
    validates :trial_baskets_count,
      numericality: { greater_than_or_equal_to: 0 },
      presence: true
  end

  def trial_baskets?
    trial_baskets_count.positive?
  end
end
