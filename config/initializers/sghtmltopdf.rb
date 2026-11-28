# frozen_string_literal: true

Sghtmltopdf.configure do |config|
  config.page_size = "A4"
  config.margin_top = "0mm"
  config.margin_right = "0mm"
  config.margin_bottom = "0mm"
  config.margin_left = "0mm"
  config.disable_system_fonts = true
  config.allow_path = [
    Rails.root.join("public").to_s,
    Rails.root.join("app/assets").to_s,
    Rails.root.join("lib/assets").to_s
  ]
end
