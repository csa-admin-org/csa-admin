require 'prawn/measurement_extensions'

class InvoicePdf < Prawn::Document
  include ActionView::Helpers::NumberHelper

  attr_reader :invoice, :membership, :isr_ref

  INFO = {
    Title:        'Facture',
    Producer:     'Prawn',
    CreationDate: Time.zone.now
  }
  PAYMENT_FOR = "Banque Raiffeisen du Vignoble\n2023 Gorgier"
  IN_FAVOR_OF = "Association Rage de Vert\nClosel-Bourbon 3\n2075 Thielle"

  def initialize(invoice, view)
    super(
      page_size: 'A4',
      margin: [0, 0, 0, 0],
      info: INFO.merge(
        Author:  Current.acp.name,
        Creator: Current.acp.name))
    @invoice = invoice
    @membership = invoice.membership
    @isr_ref = ISRReferenceNumber.new(invoice.id, invoice.amount)
    setup_font('Helvetica')
    logo
    header
    member
    content
    footer
    isr
  end

  def setup_font(name)
    font_path = "#{Rails.root}/lib/assets/fonts/"
    font_families.update(
      'Helvetica' => {
        normal: font_path + 'Helvetica.ttf',
        italic: font_path + 'HelveticaOblique.ttf',
        bold: font_path + 'HelveticaBold.ttf',
        bold_italic: font_path + 'HelveticaBoldOblique.ttf'
      },
      'OcrB' => {
        normal: font_path + 'OcrB.ttf'
      }
    )
    font(name)
  end

  def logo
    image "#{Rails.root}/app/assets/images/logo_big.jpg",
      at: [15, bounds.height - 20],
      width: 110
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
    bounding_box [12.cm, bounds.height - 6.cm], width: 8.cm, height: 3.5.cm do
      # stroke_bounds
      text member_address, valign: :top, leading: 2
    end
  end

  def header
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
    data = [['déscription', 'montant (CHF)']]

    if membership
      data << [membership.description, nil]
      data << [membership.basket_description, cur(membership.basket_total_price)]
      data << [membership.distribution_description, cur(membership.distribution_total_price)]
      unless membership.halfday_works_total_price.zero?
        data << [membership.halfday_works_description, cur(membership.halfday_works_total_price)
        ]
      end
    end

    if invoice.paid_memberships_amount.to_f > 0
      data << ['Déjà facturé', cur(-invoice.paid_memberships_amount)]
    end

    if invoice.remaining_memberships_amount?
      data << ['Montant restant', cur(invoice.remaining_memberships_amount)]
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

    table data, column_widths: [bounds.width - 130, 70], position: :center do |t|
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
          t.row(-3).font_style = :bold

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
      text 'Payable dans les 30 jours, avec nos remerciements.',
        width: 200,
        align: :right,
        style: :italic,
        size: 9
    end
  end

  def footer
    font_size 10
    bounding_box [0, 300], width: bounds.width, height: 50 do
      text \
        '<b>Association Rage de Vert</b>, ' +
          'Closel-Bourbon 3, 2075 Thielle /// ' +
          'info@ragedevert.ch, 076 481 13 84',
        inline_format: true,
        align: :center
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
        text_box PAYMENT_FOR, at: [x, y - 25], width: 120, height: 50, leading: 2
        text_box IN_FAVOR_OF, at: [x, y - 62], width: 120, height: 50, leading: 2
        text_box "N° facture: #{invoice.id}",
          at: [x, y - 108],
          width: 120,
          height: 50
      end
      font('OcrB')
      [87, 260].each do |x|
        text_box ISRReferenceNumber::CCP,
          at: [x, y - 120],
          width: 100,
          height: 50,
          size: 10,
          character_spacing: 1
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
      text_box isr_ref.ref.remove(' '),
        at: [10, y - 173],
        width: 180,
        height: 50,
        character_spacing: 0.6
      text_box isr_ref.ref,
        at: [360, y - 97],
        width: 380,
        height: 50,
        size: 10,
        character_spacing: 0.8
      text_box isr_ref.full_ref,
        at: [200, y - 245],
        width: 500,
        height: 50,
        size: 10,
        character_spacing: 1
    end
  end
end
