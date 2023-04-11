class AddFirstMembershipToNewsletterSegments < ActiveRecord::Migration[7.0]
  def change
    add_column :newsletter_segments, :first_membership, :boolean
  end
end
