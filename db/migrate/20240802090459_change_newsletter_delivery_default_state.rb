class ChangeNewsletterDeliveryDefaultState < ActiveRecord::Migration[7.1]
  def change
    change_column_default :newsletter_deliveries, :state, from: "pending", to: "processing"

    up_only do
      if Tenant.inside?
        Newsletter::Delivery.where(state: "pending").update_all(state: "processing")
      end
    end
  end
end
