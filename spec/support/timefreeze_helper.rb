RSpec.configure do |config|
  config.around(:example) do |example|
    if date = example.metadata[:freeze]
      travel_to(date) { example.run }
    else
      example.run
    end
  end
end
