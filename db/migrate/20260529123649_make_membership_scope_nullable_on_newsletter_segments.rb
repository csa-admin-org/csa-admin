# frozen_string_literal: true

class MakeMembershipScopeNullableOnNewsletterSegments < ActiveRecord::Migration[8.1]
  def change
    change_column_null :newsletter_segments, :membership_scope, true
    change_column_default :newsletter_segments, :membership_scope, nil
  end
end
