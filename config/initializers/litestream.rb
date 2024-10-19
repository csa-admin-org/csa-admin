Rails.application.configure do
  litestream_credentials = Rails.application.credentials.litestream
  config.litestream.replica_bucket = litestream_credentials&.replica_bucket
  config.litestream.replica_key_id = litestream_credentials&.replica_key_id
  config.litestream.replica_access_key = litestream_credentials&.replica_access_key

  config.litestream.username = "mc"
  config.litestream.password = ENV["MISSION_CONTROL_PASSWORD"]
end
