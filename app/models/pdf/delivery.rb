module PDF
  class Delivery < Base
    attr_reader :delivery, :current_time

    def initialize(delivery, distribution = nil)
      @delivery = delivery
      super
      @current_time = Time.current
      basket_ids = delivery.baskets.not_empty.pluck(:id)
      @baskets = Basket.where(id: basket_ids).includes(:member, :baskets_basket_complements).order('members.name')
      @distributions =
        if distribution
          [distribution]
        else
          Distribution.where(id: @baskets.pluck(:distribution_id).uniq).order(:name)
        end

      @distributions.each do |distribution|
        page(distribution)
        start_new_page unless @distributions.last == distribution
      end
    end

    def info
      super.merge(Title: "Fiches Signature #{delivery.date}")
    end

    def filename
      "fiches-signature-#{delivery.date}.pdf"
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

    def page(distribution)
      logo
      header(distribution)
      content(distribution)
      footer
    end

    def logo
      image acp_logo_io, at: [15, bounds.height - 20], width: 110
    end

    def header(distribution)
      bounding_box [bounds.width - 320, bounds.height - 20], width: 300, height: 100 do
        text distribution.name, size: 28, align: :right
        move_down 5
        text I18n.l(delivery.date), size: 28, align: :right
      end
    end

    def content(distribution)
      font_size 11
      move_down 4.cm

      baskets = @baskets.where(distribution: distribution)
      basket_ids = baskets.pluck(:basket_size_id).uniq
      complement_ids = baskets.joins(:baskets_basket_complements).pluck(:basket_complement_id).uniq
      basket_sizes = BasketSize.where(id: basket_ids).order(:name)
      complements = BasketComplement.where(id: complement_ids).order(:name)


      member_name_width = 280
      signature_width = 100
      width = member_name_width + (basket_sizes.size + complements.size) * 25 + signature_width

      # Headers
      bounding_box [(bounds.width - width) / 2, cursor], width: width, height: 20, position: :center do
        text_box '', width: member_name_width, at: [0, cursor]
        basket_sizes.each_with_index do |bs, i|
          text_box bs.name,
            rotate: 45,
            at: [member_name_width + i * 25 + 5, cursor],
            valign: :bottom
        end
        complements.each_with_index do |c, i|
          text_box c.name,
            rotate: 45,
            at: [member_name_width + basket_sizes.size * 25 + i * 25 + 5, cursor],
            valign: :bottom
        end
        text_box 'Signature',
          width: signature_width,
          at: [member_name_width + (basket_sizes.size + complements.size) * 25, cursor],
          align: :right,
          valign: :center
      end

      font_size 12
      data = []
      baskets.each do |basket|
        line = [
          content: basket.member.name,
          width: member_name_width,
          height: 25,
          align: :right,
          padding_right: 15
        ]
        basket_sizes.each do |bs|
          line << {
            content: (basket.basket_size_id == bs.id ? display_quantity(basket.quantity) : ''),
            width: 25,
            height: 25,
            align: :center
          }
        end
        complements.each do |c|
          line << {
            content: (basket.baskets_basket_complements.map(&:basket_complement_id).include?(c.id) ? display_quantity(basket.baskets_basket_complements.find { |bbc| bbc.basket_complement_id == c.id }.quantity) : ''),
            width: 25,
            height: 25,
            align: :center
          }
        end
        line << { content: '', width: signature_width }
        data << line
      end
      data << data.last.size.times.map { '' }

      table(data,
          row_colors: ['DDDDDD', 'FFFFFF'],
          cell_style: { border_width: 0.5, border_color: 'AAAAAA' },
          position: :center) do |t|
        t.cells.borders = []
        (basket_sizes.size + complements.size).times do |i|
          t.columns(1 + i).borders = [:left, :right]

          t.row(-1).borders = [:top]
          t.row(-1).border_color = 'DDDDDD'
          t.row(-1).background_color = 'FFFFFF'
        end
      end
    end

    def footer
      font_size 8
      bounding_box [0, 20], width: bounds.width, height: 50 do
        text "– #{I18n.l(current_time, format: :short)} –", inline_format: true, align: :center
      end
    end

    def display_quantity(quantity)
      quantity.zero? ? '' : quantity.to_s
    end
  end
end
