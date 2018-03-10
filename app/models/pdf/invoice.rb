module PDF
  class Invoice < Base
    include MembershipsHelper

    attr_reader :invoice, :membership, :isr_ref

    def initialize(invoice)
      @invoice = invoice
      super
      @membership = invoice.membership
      @isr_ref = ISRReferenceNumber.new(invoice.id, invoice.amount)
      header
      member
      content
      footer
      isr
    end

    private

    def info
      super.merge(Title: "Facture #{invoice.id}")
    end

    def member_address
      member = invoice.member
      [
        member.name,
        member.address.capitalize,
        "#{member.zip} #{member.city}"
      ].join("\n")
    end

    def member
      bounding_box [12.cm, bounds.height - 6.cm], width: 8.cm, height: 3.cm do
        # stroke_bounds
        text member_address, valign: :top, leading: 2
      end
    end

    def header
      image acp_logo_io, at: [15, bounds.height - 20], width: 110
      bounding_box [25, bounds.height - 6.cm], width: 200, height: 40 do
        text "Facture N° #{invoice.id}", style: :bold, size: 16
        move_down 5
        text I18n.l(invoice.date)
      end
    end

    def cur(amount)
      number_to_currency(amount, unit: '')
    end

    def content
      font_size 10
      data = [['description', 'montant (CHF)']]

      if membership
        data << [membership_period, nil]
        if membership.basket_sizes_price.positive?
          membership.basket_sizes.uniq.each do |basket_size|
            data << [
              membership_basket_size_description(basket_size),
              cur(membership.basket_size_total_price(basket_size))
            ]
          end
        end
        unless membership.baskets_annual_price_change.zero?
          data << ['Ajustement du prix des paniers', cur(membership.baskets_annual_price_change)]
        end
        if membership.basket_complements_price.positive?
          membership.basket_complements.uniq.each do |basket_complement|
            data << [
              membership_basket_complement_description(basket_complement),
              cur(membership.basket_complement_total_price(basket_complement))
            ]
          end
        end
        membership.distributions.uniq.each do |distribution|
          price = membership.distribution_total_price(distribution)
          if price.positive?
            data << [
              membership_distribution_description(distribution),
              cur(price)
            ]
          end
        end
        unless membership.halfday_works_annual_price.zero?
          data << [halfday_works_annual_price_description, cur(membership.halfday_works_annual_price)]
        end
      end

      if invoice.paid_memberships_amount.to_f > 0
        data << ["Déjà facturé", cur(-invoice.paid_memberships_amount)]
        data << ['Montant annuel restant', cur(invoice.remaining_memberships_amount)]
      elsif invoice.remaining_memberships_amount?
        data << ['Montant annuel', cur(invoice.remaining_memberships_amount)]
      end

      if invoice.memberships_amount?
        data << [
          invoice.memberships_amount_description,
          cur(invoice.memberships_amount)
        ]
      end

      if invoice.support_amount?
        data << ['Cotisation annuelle association', cur(invoice.support_amount)]
      end

      if invoice.memberships_amount? && invoice.support_amount?
        data << ['Total', number_to_currency(invoice.amount, unit: '')]
      end

      table data, column_widths: [bounds.width - 120, 70], position: :center do |t|
        t.cells.borders = []
        t.cells.valign = :bottom
        t.cells.align = :right
        t.cells.inline_format = true
        t.cells.leading = 1

        t.columns(0).padding_right = 15
        t.columns(1).padding_left = 0
        t.columns(1).padding_right = 0
        t.row(0).borders = [:bottom]
        t.row(0).font_style = :bold
        t.rows(2..-1).padding_top = 0

        t.columns(0).rows(1..-1).filter do |cell|
          if cell.content == 'Déjà facturé'
            t.row(cell.row).font_style = :italic
            break
          end
        end
        t.columns(1).rows(1..-1).filter do |cell|
          t.row(cell.row).font_style = :italic if cell.content == ''
        end

        if invoice.memberships_amount? &&
            (invoice.support_amount? || !invoice.memberships_amount_description?)
          t.columns(1).rows(-1).borders = [:top]
          t.row(-1).font_style = :bold
          t.row(-1).padding_top = 0
          t.row(-2).padding_bottom = 10
        end

        if invoice.memberships_amount_description?
          if invoice.support_amount?
            t.columns(1).rows(-4).borders = [:top]
            t.row(-4).padding_top = 0
            t.row(-4).padding_bottom = 15
            t.row(-5).padding_bottom = 10
          else
            t.row(-1).font_style = :bold

            t.columns(1).rows(-2).borders = [:top]
            t.row(-2).padding_top = 0
            t.row(-2).padding_bottom = 15
            t.row(-3).padding_bottom = 10
          end
        end
      end

      bounding_box [0, y - 30], width: bounds.width - 28, height: 50 do
        text Current.acp.invoice_info, width: 200, align: :right, style: :italic, size: 9
      end
    end

    def footer
      font_size 10
      bounding_box [0, 300], width: bounds.width, height: 50 do
        text Current.acp.invoice_footer, inline_format: true, align: :center
      end
    end

    def isr
      y = 273
      font_size 8
      bounding_box [0, y], width: bounds.width, height: y do
        image "#{Rails.root}/app/assets/images/isr.jpg",
          at: [0, y],
          width: bounds.width
        [10, 185].each do |x|
          text_box Current.acp.isr_payment_for, at: [x, y - 25], width: 120, height: 50, leading: 2
          text_box Current.acp.isr_in_favor_of, at: [x, y - 62], width: 120, height: 50, leading: 2
          text_box "N° facture: #{invoice.id}",
            at: [x, y - 108],
            width: 120,
            height: 50
        end
        font('OcrB')
        [87, 260].each do |x|
          text_box Current.acp.ccp,
            at: [x, y - 120],
            width: 100,
            height: 50,
            size: 11,
            character_spacing: 0.6
        end
        [64, 238].each do |x|
          text_box invoice.amount.to_i.to_s,
            at: [x, y - 145],
            width: 50,
            height: 50,
            character_spacing: 0.8,
            size: 12,
            align: :right
          text_box isr_ref.amount_cents,
            at: [x + 75, y - 145],
            width: 50,
            height: 50,
            size: 12,
            character_spacing: 0.8
        end
        text_box isr_ref.ref,
          at: [354, y - 97],
          width: 370,
          height: 50,
          size: 11,
          character_spacing: 0.6
        text_box isr_ref.full_ref,
          at: [185, y - 241],
          width: 390,
          height: 50,
          size: 11,
          align: :right,
          character_spacing: 0.6
      end
    end

    def membership_period
      "Période du #{membership_short_period(membership)}"
    end

    def membership_basket_size_description(basket_size)
      baskets = membership.baskets.where(basket_size: basket_size)
      "Panier: #{basket_size.name} #{basket_sizes_price_info(baskets)}"
    end

    def membership_basket_complement_description(basket_complement)
      baskets =
        membership
          .baskets
          .joins(:baskets_basket_complements)
          .where(baskets_basket_complements: { basket_complement: basket_complement })
      "#{basket_complement.name} #{basket_complements_price_info(baskets)}"
    end

    def membership_distribution_description(distribution)
      baskets = membership.baskets.where(distribution: distribution)
      "Distribution: #{distribution.name} #{distributions_price_info(baskets)}"
    end

    def halfday_works_annual_price_description
      i18n_scope = Current.acp.halfday_i18n_scope
      diff = membership.annual_halfday_works - membership.basket_size.annual_halfday_works
      if diff.positive?
        Membership.human_attribute_name("halfday_works_annual_price_reduction/#{i18n_scope}", count: diff)
      elsif diff.negative?
        Membership.human_attribute_name("halfday_works_annual_price_negative/#{i18n_scope}", count: diff)
      elsif membership.halfday_works_annual_price.positive?
        Membership.human_attribute_name("halfday_works_annual_price_positive/#{i18n_scope}")
      else
        Membership.human_attribute_name("halfday_works_annual_price_default/#{i18n_scope}")
      end
    end
  end
end
