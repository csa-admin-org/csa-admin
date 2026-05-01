# frozen_string_literal: true

module PDF
  class SEPAMandate < Base
    attr_reader :member, :mandate

    def initialize(mandate)
      @mandate = mandate
      @member = mandate.member
      super
      generate
    end

    def filename
      "sepa_mandate_#{mandate.umr}_#{mandate.signed_on}.pdf"
    end

    private

    def generate
      header
      bounding_box(
        [ 25.mm, bounds.height - 90.mm ],
        width: bounds.width - 50.mm
      ) do
        summary
        move_down 20.mm
        mandate_text
      end
      bounding_box(
        [ 25.mm, 25.mm ],
        width: bounds.width - 50.mm
      ) do
        evidence_footer
      end
    end

    def header
      logo_width = 40.mm
      image org_logo_io(size: 160),
        at: [ (bounds.width - logo_width) / 2.0, bounds.height - 15.mm ],
        width: logo_width

      bounding_box(
        [ 0, bounds.height - 60.mm ],
        width: bounds.width
      ) do
        font_size 18
        text I18n.t("sepa_mandate.pdf.title"), style: :bold, align: :center
      end
    end

    def summary
      font_size 10
      data = [
        [
          I18n.t("sepa_mandate.pdf.creditor"),
          [
            Current.org.creditor_name,
            Current.org.creditor_street,
            "#{Current.org.creditor_zip} #{Current.org.creditor_city}"
          ].compact.join("\n")
        ],
        [
          I18n.t("sepa_mandate.pdf.creditor_identifier"),
          Current.org.sepa_creditor_identifier.to_s
        ],
        [
          I18n.t("sepa_mandate.pdf.debtor"),
          [
            member.billing_info(:name),
            member.billing_info(:street),
            "#{member.billing_info(:zip)} #{member.billing_info(:city)}"
          ].compact.join("\n")
        ],
        [
          I18n.t("sepa_mandate.pdf.iban"),
          mandate.iban.to_s.scan(/.{1,4}/).join(" ")
        ],
        [
          I18n.t("sepa_mandate.pdf.mandate_reference"),
          mandate.umr
        ],
        [
          I18n.t("sepa_mandate.pdf.signed_on"),
          I18n.l(mandate.signed_on)
        ]
      ]

      table(data, cell_style: { borders: [], padding: [ 5, 0, 5, 0 ], leading: 3 }) do
        column(0).font_style = :bold
        column(0).width = 60.mm
      end
    end

    def mandate_text
      font_size 10
      interp = {
        creditor_name: Current.org.creditor_name,
        creditor_street: Current.org.creditor_street,
        creditor_zip: Current.org.creditor_zip,
        creditor_city: Current.org.creditor_city,
        sepa_creditor_identifier: Current.org.sepa_creditor_identifier,
        sepa_mandate_id: mandate.umr
      }
      text I18n.t("sepa_mandate.authorisation", **interp), leading: 3
      move_down 5.mm
      text I18n.t("sepa_mandate.refund_notice", **interp), leading: 3
    end

    # Mandate documents only need the standard SEPA fields. Detailed consent
    # evidence (timestamp, IP, user agent) is recorded in the SEPAMandate row
    # and surfaced from the admin/console for disputes; it should not
    # appear on the customer-facing PDF.
    def evidence_footer
      font_size 8
      fill_color "777777"
      text I18n.t("sepa_mandate.pdf.evidence_footer"),
        leading: 2,
        style: :italic
      fill_color "000000"
    end
  end
end
