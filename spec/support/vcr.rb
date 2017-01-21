require 'vcr'
VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.ignore_localhost = true
  c.filter_sensitive_data(ENV['RAIFFEISEN_PASSWORD']) { 'PASSWORD' }
end

require 'webmock/rspec'
