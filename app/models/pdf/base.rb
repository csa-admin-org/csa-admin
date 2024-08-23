# frozen_string_literal: true

require "prawn/measurement_extensions"

module PDF
  class Base < Prawn::Document
    include ActionView::Helpers::NumberHelper
    include ApplicationHelper

    def initialize(*_args)
      super(
        page_size: "A4",
        margin: [ 0, 0, 0, 0 ],
        info: info)
      setup_font("Helvetica")
    end

    def info
      {
        Producer: "Prawn",
        CreationDate: Time.current,
        Author:  Current.acp.name,
        Creator: Current.acp.name
      }
    end

    def content_type
      "application/pdf"
    end

    def setup_font(name)
      font_path = "#{Rails.root}/lib/assets/fonts/"
      font_families.update(
        "Helvetica" => {
          normal: font_path + "Helvetica.ttf",
          italic: font_path + "HelveticaOblique.ttf",
          bold: font_path + "HelveticaBold.ttf",
          bold_italic: font_path + "HelveticaBoldOblique.ttf"
        }
      )
      font(name)
    end

    def acp_logo_io
      logo =
        if Current.acp.logo.attached?
          Current.acp.logo.download
        else
          path = Rails.root.join("app/assets/images/logo.png")
          URI.open(path).read
        end
      StringIO.new(logo)
    end
  end
end
