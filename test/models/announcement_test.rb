# frozen_string_literal: true

require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  test "must be unique per depot and delivery" do
    delivery = deliveries(:monday_1)
    depot = depots(:farm)
    Announcement.create!(
      text: "Bring back the bags!",
      depot_ids: [ depot.id ],
      delivery_ids: [ delivery.id ])

    announcement = Announcement.new(
      text: "No delivery next week",
      depot_ids: [ depot.id ],
      delivery_ids: [ delivery.id ])

    assert_not announcement.valid?
    assert_includes announcement.errors[:base].first,
      "There is already an announcement for the delivery of"
  end
end
