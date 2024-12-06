# frozen_string_literal: true

Rails.application.configure do
  litestream_credentials = Rails.application.credentials.litestream
  config.litestream.replica_bucket = litestream_credentials&.replica_bucket
  config.litestream.replica_key_id = litestream_credentials&.replica_key_id
  config.litestream.replica_access_key = litestream_credentials&.replica_access_key

  config.litestream.username = Rails.application.credentials.http_basic_auth_user
  config.litestream.password = Rails.application.credentials.http_basic_auth_password
end
