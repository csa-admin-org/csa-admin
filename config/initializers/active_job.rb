class ActiveJob::Base
  # Don't use that when using inline jobs
  unless Rails.env.test?
    include Apartment::ActiveJob
  end
end
