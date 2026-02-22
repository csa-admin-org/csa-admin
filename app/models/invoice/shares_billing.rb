# frozen_string_literal: true

module Invoice::SharesBilling
  extend ActiveSupport::Concern

  included do
    validates :shares_number,
      numericality: { other_than: 0, allow_blank: true }
    validates :shares_number, absence: true, unless: :share_type?
    validates :items, absence: true, if: :share_type?

    after_commit :handle_shares_change!
  end

  def shares_number=(number)
    return if number.to_i == 0

    super
    self[:entity_type] = "Share" unless entity_type?
    self[:amount] = number.to_i * Current.org.share_price
  end

  def can_refund?
    closed?
      && shares_number.to_i.positive?
      && member.shares_number.to_i.positive?
  end

  private

  def handle_shares_change!
    member.handle_shares_change! if share_type?
  end
end
