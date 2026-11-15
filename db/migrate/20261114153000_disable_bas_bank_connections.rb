# frozen_string_literal: true

class DisableBasBankConnections < ActiveRecord::Migration[8.1]
  def up
    Tenant.switch_each do
      now = Time.current
      BankConnection.where(provider: "bas").find_each do |connection|
        details = connection.status_details.to_h.deep_stringify_keys
        details["retired"] = {
          "reason" => "bas_keyfile_shutdown",
          "at" => now.iso8601
        }
        connection.update_columns(
          active: false,
          state: "disabled",
          status_details: details,
          updated_at: now)
      end
    end
  end
end
