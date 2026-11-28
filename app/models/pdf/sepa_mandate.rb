# frozen_string_literal: true

module PDF
  class SEPAMandate < Base
    SummaryRow = Data.define(:label, :lines)

    attr_reader :member, :mandate

    def initialize(mandate)
      @mandate = mandate
      @member = mandate.member
    end

    def filename
      "sepa_mandate_#{mandate.umr}_#{mandate.signed_on}.pdf"
    end

    private

    def template_path
      "pdfs/sepa_mandates/show"
    end

    def stylesheets
      %w[pdf/sepa_mandate]
    end

    def view_assigns
      {
        logo_data_uri: org_logo_data_uri(size: 160),
        summary_rows: build_summary_rows,
        authorisation: I18n.t("sepa_mandate.authorisation", **mandate_interpolations),
        refund_notice: I18n.t("sepa_mandate.refund_notice", **mandate_interpolations)
      }
    end

    def build_summary_rows
      [
        SummaryRow.new(
          label: I18n.t("sepa_mandate.pdf.creditor"),
          lines: [
            Current.org.creditor_name,
            Current.org.creditor_street,
            "#{Current.org.creditor_zip} #{Current.org.creditor_city}"
          ].compact
        ),
        SummaryRow.new(
          label: I18n.t("sepa_mandate.pdf.creditor_identifier"),
          lines: [ Current.org.sepa_creditor_identifier.to_s ]
        ),
        SummaryRow.new(
          label: I18n.t("sepa_mandate.pdf.debtor"),
          lines: [
            member.billing_info(:name),
            member.billing_info(:street),
            "#{member.billing_info(:zip)} #{member.billing_info(:city)}"
          ].compact
        ),
        SummaryRow.new(
          label: I18n.t("sepa_mandate.pdf.iban"),
          lines: [ mandate.iban.to_s.scan(/.{1,4}/).join(" ") ]
        ),
        SummaryRow.new(
          label: I18n.t("sepa_mandate.pdf.mandate_reference"),
          lines: [ mandate.umr.to_s ]
        ),
        SummaryRow.new(
          label: I18n.t("sepa_mandate.pdf.signed_on"),
          lines: [ I18n.l(mandate.signed_on) ]
        )
      ]
    end

    def mandate_interpolations
      @mandate_interpolations ||= {
        creditor_name: Current.org.creditor_name,
        creditor_street: Current.org.creditor_street,
        creditor_zip: Current.org.creditor_zip,
        creditor_city: Current.org.creditor_city,
        sepa_creditor_identifier: Current.org.sepa_creditor_identifier,
        sepa_mandate_id: mandate.umr
      }
    end
  end
end
