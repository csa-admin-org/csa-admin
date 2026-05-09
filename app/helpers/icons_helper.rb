# frozen_string_literal: true

module IconsHelper
  def icon(name, options = {})
    inline_svg_tag("icons/#{name}.svg", options)
  end

  def simpleicons(name, options = {})
    inline_svg_tag("simpleicons/#{name}.svg", options)
  end
end
