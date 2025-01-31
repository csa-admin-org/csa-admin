# frozen_string_literal: true

InlineSvg.configure do |config|
  config.raise_on_file_not_found = !Rails.env.production?
end
