# frozen_string_literal: true

require "test_helper"

class DateAbbreviationsTest < ActiveSupport::TestCase
  test "French abbreviated August keeps the circumflex" do
    I18n.with_locale(:fr) do
      assert_equal "Aoû", I18n.t("date.abbr_month_names")[8]
      assert_equal "Fév", I18n.t("date.abbr_month_names")[2]
      assert_equal "Déc", I18n.t("date.abbr_month_names")[12]
      assert_equal "Lun. 17 Aoû 26", I18n.l(Date.new(2026, 8, 17), format: :medium)
    end
  end
end
