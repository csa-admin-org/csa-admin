class AddLastTrialBasketSentAtToMemberships < ActiveRecord::Migration[6.1]
  def change
    add_column :memberships, :last_trial_basket_sent_at, :datetime
  end
end
