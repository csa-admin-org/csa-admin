# frozen_string_literal: true

require "fileutils"

module Geocoding::Nominatim
  LOCK_FILE = Rails.root.join("tmp", "nominatim-geocoding.lock")
  TIMESTAMP_FILE = Rails.root.join("tmp", "nominatim-geocoding.last")

  def self.search(address)
    throttle
    Geocoder.search(address, limit: 1)
  end

  def self.throttle
    interval = Rails.application.config.x.geocoding.minimum_interval
    return if interval.zero?

    FileUtils.mkdir_p(LOCK_FILE.dirname)
    File.open(LOCK_FILE, File::RDWR | File::CREAT, 0o644) do |file|
      file.flock(File::LOCK_EX)
      wait_until_allowed(interval)
      TIMESTAMP_FILE.write(Time.current.to_f.to_s)
    ensure
      file.flock(File::LOCK_UN)
    end
  end

  def self.wait_until_allowed(interval)
    return unless TIMESTAMP_FILE.exist?

    timestamp = TIMESTAMP_FILE.read
    return if timestamp.blank?

    last_request_at = Float(timestamp)
    delay = interval.to_f - (Time.current.to_f - last_request_at)
    sleep(delay) if delay.positive?
  rescue ArgumentError, TypeError
    nil
  end
end
