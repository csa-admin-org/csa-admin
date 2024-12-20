# frozen_string_literal: true

Rails.application.config.after_initialize do
  env = Liquid::Environment.default
  env.error_mode = :strict

  env.register_tag("button", Liquid::ButtonBlock)
  env.register_tag("lowlight", Liquid::LowlightBlock)
  env.register_tag("highlight", Liquid::HighlightBlock)
  env.register_tag("highlight_list", Liquid::HighlightListBlock)
  env.register_tag("content", Liquid::ContentBlock)
end
