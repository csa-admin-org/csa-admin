class AddBillingYearDivisionToNewsletterSegments < ActiveRecord::Migration[7.1]
  def change
    add_column :newsletter_segments, :billing_year_division, :integer
  end
end
