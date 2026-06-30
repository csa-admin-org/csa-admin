# frozen_string_literal: true

require "test_helper"

class Geocoding::NominatimTest < ActiveSupport::TestCase
  setup do
    @previous_interval = Rails.application.config.x.geocoding.minimum_interval
    @original_lock_file = Geocoding::Nominatim::LOCK_FILE
    @original_timestamp_file = Geocoding::Nominatim::TIMESTAMP_FILE
    @lock_file = Rails.root.join("tmp", "nominatim-geocoding-#{Process.pid}-#{object_id}.lock")
    @timestamp_file = Rails.root.join("tmp", "nominatim-geocoding-#{Process.pid}-#{object_id}.last")

    Rails.application.config.x.geocoding.minimum_interval = 1.second
    set_nominatim_paths(@lock_file, @timestamp_file)
    FileUtils.rm_f(@timestamp_file)
    FileUtils.rm_f(@lock_file)
  end

  teardown do
    Rails.application.config.x.geocoding.minimum_interval = @previous_interval
    FileUtils.rm_f(@timestamp_file)
    FileUtils.rm_f(@lock_file)
    set_nominatim_paths(@original_lock_file, @original_timestamp_file)
  end

  test "throttle allows first request without an existing timestamp" do
    assert_nothing_raised { Geocoding::Nominatim.throttle }
    assert @timestamp_file.exist?
  end

  test "throttle allows request when timestamp is malformed" do
    FileUtils.mkdir_p(@timestamp_file.dirname)
    @timestamp_file.write("not-a-time")

    assert_nothing_raised { Geocoding::Nominatim.throttle }
    assert_match(/\A\d/, @timestamp_file.read)
  end

  private

  def set_nominatim_paths(lock_file, timestamp_file)
    Geocoding::Nominatim.send(:remove_const, :LOCK_FILE)
    Geocoding::Nominatim.const_set(:LOCK_FILE, lock_file)
    Geocoding::Nominatim.send(:remove_const, :TIMESTAMP_FILE)
    Geocoding::Nominatim.const_set(:TIMESTAMP_FILE, timestamp_file)
  end
end
