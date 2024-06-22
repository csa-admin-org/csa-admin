# frozen_string_literal: true

class ChangeAbsencesIncludedAnnuallyDefault < ActiveRecord::Migration[7.1]
  def change
    change_column_default :memberships, :absences_included_annually, from: 0, to: nil
  end
end
