# frozen_string_literal: true

require "test_helper"

class Billing::SnapshotTest < ActiveSupport::TestCase
  test "creates a new snapshot" do
    travel_to "2020-03-31 23:59:55 +02"

    snapshot = nil
    assert_difference 'Billing::Snapshot.count', 1 do
      snapshot = Billing::Snapshot.create_or_update_current_quarter!
    end

    assert snapshot.file.present?
    assert_equal "acme-billing-20200331-23h59.xlsx", snapshot.file.filename.to_s
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", snapshot.file.content_type
  end

  test "updates an existing quarter snapshot" do
    travel_to "2020-03-31 23:59:55 +02"
    snapshot = Billing::Snapshot.create_or_update_current_quarter!

    travel_to "2020-03-31 23:59:59 +02"

    assert_no_difference 'Billing::Snapshot.count' do
      snapshot = Billing::Snapshot.create_or_update_current_quarter!
    end

    assert snapshot.file.present?
    assert_equal "acme-billing-20200331-23h59.xlsx", snapshot.file.filename.to_s
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", snapshot.file.content_type
  end

  test "does not create a new snapshot when it is too late" do
    travel_to "2020-04-01 00:10:00 +02"

    assert_no_difference 'Billing::Snapshot.count' do
      Billing::Snapshot.create_or_update_current_quarter!
    end
  end
end
