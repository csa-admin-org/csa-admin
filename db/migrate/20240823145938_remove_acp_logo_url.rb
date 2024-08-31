# frozen_string_literal: true

class RemoveAcpLogoUrl < ActiveRecord::Migration[7.2]
  def change
    remove_column :acps, :logo_url, :string
  end
end
