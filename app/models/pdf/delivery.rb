module PDF
  class Delivery < Base
    BASKETS_PER_PAGE = 20

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

      @distributions.each do |dist|
        baskets = @baskets.where(distribution: dist)
        basket_sizes = basket_sizes_for(baskets)
        basket_complements = basket_complements_for(baskets)
        total_pages = (baskets.count / BASKETS_PER_PAGE.to_f).ceil

        baskets.each_slice(BASKETS_PER_PAGE).with_index do |slice, i|
          page_n =  i + 1
          page(dist, slice, basket_sizes, basket_complements, page: page_n, total_pages: total_pages)
          start_new_page unless page_n == total_pages
        end
        start_new_page unless @distributions.last == dist
      end
    end

    def filename
      "fiches-signature-#{delivery.date}.pdf"
    end

    private

    def info
      super.merge(Title: "Fiches Signature #{delivery.date}")
    end

    def page(distribution, baskets, basket_sizes, basket_complements, page:, total_pages:)
      header(distribution, page: page, total_pages: total_pages)
      content(distribution, baskets, basket_sizes, basket_complements)
      footer
    end

    def header(distribution, page:, total_pages:)
      image acp_logo_io, at: [15, bounds.height - 20], width: 110
      bounding_box [bounds.width - 320, bounds.height - 20], width: 300, height: 100 do
        text distribution.name, size: 28, align: :right
        move_down 5
        text I18n.l(delivery.date), size: 28, align: :right
        if total_pages > 1
          move_down 5
          text "#{page} / #{total_pages}", size: 28, align: :right
        end
      end
    end

    def content(distribution, baskets, basket_sizes, basket_complements)
      font_size 11
      move_down 3.5.cm

      bs_size = basket_sizes.size
      bc_size = basket_complements.size

      member_name_width = 280
      signature_width = 100
      width = member_name_width + (bs_size + bc_size) * 25 + signature_width

      # Headers
      bounding_box [(bounds.width - width) / 2, cursor], width: width, height: 20, position: :center do
        text_box '', width: member_name_width, at: [0, cursor]
        basket_sizes.each_with_index do |bs, i|
          text_box bs.name,
            rotate: 45,
            at: [member_name_width + i * 25 + 5, cursor],
            valign: :bottom
        end
        basket_complements.each_with_index do |c, i|
          text_box c.name,
            rotate: 45,
            at: [member_name_width + bs_size * 25 + i * 25 + 5, cursor],
            valign: :bottom
        end
        text_box 'Signature',
          width: signature_width,
          at: [member_name_width + (bs_size + bc_size) * 25, cursor],
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
        basket_complements.each do |c|
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

      total_line = [
        content: 'Total',
        width: member_name_width,
        height: 25,
        align: :right,
        padding_right: 15
      ]
      basket_sizes.each do |bs|
        baskets_with_size = baskets.select { |b| b.basket_size_id == bs.id }
        total_line << {
          content: baskets_with_size.sum(&:quantity).to_s,
          width: 25,
          height: 25,
          align: :center
        }
      end
      basket_complements.each do |c|
        baskets_basket_complements = baskets.flat_map(&:baskets_basket_complements).select { |bbc| bbc.basket_complement_id == c.id }
        total_line << {
          content: baskets_basket_complements.sum(&:quantity).to_s,
          width: 25,
          height: 25,
          align: :center
        }
      end
      data << (total_line << { content: '', width: signature_width })

      table(data,
          row_colors: ['DDDDDD', 'FFFFFF'],
          cell_style: { border_width: 0.5, border_color: 'AAAAAA' },
          position: :center) do |t|
        t.cells.borders = []
        (bs_size + bc_size).times do |i|
          t.columns(1 + i).borders = [:left, :right]

          t.row(-1).size = 11
          t.row(-1).font_style = :bold
          t.row(-1).borders = [:top]
          t.row(-1).border_color = 'DDDDDD'
          t.row(-1).background_color = 'FFFFFF'
        end
      end
    end

    def footer
      font_size 8
      bounding_box [0, 40], width: bounds.width do
        footer_text = Current.acp.delivery_pdf_footer
        if footer_text.present?
          text footer_text, align: :center
        end
        move_down 5
        text "– #{I18n.l(current_time, format: :short)} –", inline_format: true, align: :center
      end
    end

    def display_quantity(quantity)
      quantity.zero? ? '' : quantity.to_s
    end

    def basket_sizes_for(baskets)
      basket_size_ids = baskets.pluck(:basket_size_id).uniq
      BasketSize.where(id: basket_size_ids).order(:name)
    end

    def basket_complements_for(baskets)
      complement_ids = baskets.joins(:baskets_basket_complements).pluck(:basket_complement_id).uniq
      BasketComplement.where(id: complement_ids).order(:name)
    end
  end
end
