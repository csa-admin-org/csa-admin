# frozen_string_literal: true

module IconsHelper
  def icon(name, options = {})
    options[:variant] ||= "outline"
    path = "icons/#{options[:variant]}/#{name}.svg"
    inline_svg_tag(path, options)
  end
end
