# frozen_string_literal: true

module Demo::Seeder::Promotions
  extend ActiveSupport::Concern

  private

  def create_promotions!
    log "Creating promotions..."
    Promotion.create!(
      names: translated_text("Gift voucher"),
      amount: 40,
      max_uses: 1)
    Promotion.create!(
      names: translated_text("Spring offer"),
      amount: 20,
      ends_on: Date.new(Date.current.year, 12, 31))
  end
end
