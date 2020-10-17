class ActiveJob::Base
  # Don't use that when using inline jobs
  unless Rails.env.test?
    include Apartmentable
  end
end
