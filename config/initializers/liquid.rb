Liquid::Template.error_mode = :strict

Rails.application.config.after_initialize do
  Liquid::Template.register_tag('button', Liquid::ButtonBlock)
  Liquid::Template.register_tag('highlight', Liquid::HighlightBlock)
  Liquid::Template.register_tag('highlight_list', Liquid::HighlightListBlock)

  Liquid::Template.register_tag('content', Liquid::ContentBlock)
end
