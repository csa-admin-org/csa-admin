class AddComingDeliveriesInDaysToNewsletterSegments < ActiveRecord::Migration[7.0]
  def change
    add_column :newsletter_segments, :coming_deliveries_in_days, :integer
  end
end
