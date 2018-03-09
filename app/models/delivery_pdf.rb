require 'prawn/measurement_extensions'

class DeliveryPDF < Prawn::Document
  include ActionView::Helpers::NumberHelper

  attr_reader :delivery, :distribution, :baskets

  INFO = {
    Title:        'Signatures',
    Producer:     'Prawn',
    CreationDate: Time.current
  }

  def initialize(delivery, distribution)
    super(
      page_size: 'A4',
      margin: [0, 0, 0, 0],
      info: INFO.merge(
        Author:  Current.acp.name,
        Creator: Current.acp.name))
    @delivery = delivery
    @distribution = distribution
    @baskets = delivery.baskets
      .where(distribution: distribution)
      .includes(:member, :baskets_basket_complements)
    setup_font('Helvetica')
    logo
    header
    content
    footer
  end

  def setup_font(name)
    font_path = "#{Rails.root}/lib/assets/fonts/"
    font_families.update(
      'Helvetica' => {
        normal: font_path + 'Helvetica.ttf',
        italic: font_path + 'HelveticaOblique.ttf',
        bold: font_path + 'HelveticaBold.ttf',
        bold_italic: font_path + 'HelveticaBoldOblique.ttf'
      }
    )
    font(name)
  end

  def logo
    logo_io = StringIO.new(Current.acp.logo.download)
    image logo_io, at: [15, bounds.height - 20], width: 110
  end

  def header
    bounding_box [bounds.width - 320, bounds.height - 20], width: 300, height: 100 do
      text @distribution.name, size: 28, align: :right
      move_down 5
      text I18n.l(@delivery.date), size: 28, align: :right
    end
  end

  def content
    font_size 10
    move_down 5.cm

    basket_ids = baskets.pluck(:basket_size_id).uniq
    complement_ids = baskets.joins(:baskets_basket_complements).pluck(:basket_complement_id).uniq
    basket_sizes = BasketSize.where(id: basket_ids).order(:name)
    complements = BasketComplement.where(id: complement_ids).order(:name)

    member_name_width = 250
    signature_width = 150
    width = member_name_width + (basket_sizes.size + complements.size) * 20 + signature_width

    # Headers
    bounding_box [(bounds.width - width) / 2, cursor], width: width, height: 20, position: :center do
      text_box '', width: member_name_width, at: [0, cursor]
      basket_sizes.each_with_index do |bs, i|
        text_box "Panier: #{bs.name}", rotate: 45, at: [member_name_width + i * 20 + 5, cursor], valign: :bottom
      end
      complements.each_with_index do |c, i|
        text_box c.name, rotate: 45, at: [member_name_width + basket_sizes.size * 20 + i * 20 + 5, cursor], valign: :bottom
      end
      text_box 'Signature',
        width: signature_width,
        at: [member_name_width + (basket_sizes.size + complements.size) * 20, cursor],
        align: :right,
        valign: :center
    end

    font_size 12
    data = []
    baskets.each do |basket|
      line = [
        content: basket.member.name,
        width: member_name_width,
        height: 20,
        align: :right,
        padding_right: 10
      ]
      basket_sizes.each do |bs|
        line << {
          content: (basket.basket_size_id == bs.id ? basket.quantity.to_s : ''),
          width: 20,
          align: :center
        }
      end
      complements.each do |c|
        line << {
          content: (basket.baskets_basket_complements.map(&:basket_complement_id).include?(c.id) ? basket.baskets_basket_complements.find { |bbc| bbc.basket_complement_id == c.id }.quantity.to_s : ''),
          width: 20,
          align: :center
        }
      end
      line << { content: '', width: signature_width }
      data << line
    end

    table(data,
        row_colors: ["F1F1F1", "FFFFFF"],
        cell_style: { border_width: 0.5, border_color: 'BBBBBB' },
        position: :center) do |t|
      t.cells.borders = []
      (basket_sizes.size + complements.size).times do |i|
        t.columns(1 + i).borders = [:left, :right]
      end
    end
  end

  def footer
    font_size 8
    bounding_box [0, 20], width: bounds.width, height: 50 do
      text "– #{I18n.l(Time.current, format: :short)} –", inline_format: true, align: :center
    end
  end
end
