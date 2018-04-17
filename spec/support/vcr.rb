require 'vcr'
VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.ignore_localhost = true
  c.ignore_request { |_req| !!ENV['POSTMARK_TO'] }
end

require 'webmock/rspec'
