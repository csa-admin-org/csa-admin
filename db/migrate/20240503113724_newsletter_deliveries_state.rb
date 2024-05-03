class NewsletterDeliveriesState < ActiveRecord::Migration[7.1]
  def change
    add_column :newsletter_deliveries, :state, :string, default: "pending", null: false
    rename_column :newsletter_deliveries, :delivered_at, :processed_at
    add_column :newsletter_deliveries, :delivered_at, :datetime

    add_index :newsletter_deliveries, :state

    up_only do
      if Tenant.inside?
        Newsletter::Delivery.all.each do |delivery|
          next unless delivery.processed_at?

          if delivery.deliverable? &&
            delivery.update_columns(
              state: "delivered",
              delivered_at: delivery.processed_at)
          else
            delivery.update_columns(state: "ignored")
          end
        end
      end
    end
  end
end
