# frozen_string_literal: true

module MapsHelper
  def display_position(latitude, longitude)
    link_to [ latitude, longitude ].join(", "), "https://www.google.com/maps?q=#{latitude},#{longitude}"
  end
end
