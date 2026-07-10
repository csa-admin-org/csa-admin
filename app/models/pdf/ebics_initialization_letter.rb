# frozen_string_literal: true

require "digest"
require "time"

module PDF
  class EBICSInitializationLetter < Base
    SECTIONS = [
      [ "A006", "signature" ],
      [ "X002", "authentication" ],
      [ "E002", "encryption" ]
    ].freeze

    def initialize(bank_connection, generated_at: nil)
      @bank_connection = bank_connection
      @generated_at = (generated_at || onboarding_certificate_issued_at || Time.current).to_time
      @credentials = bank_connection.credentials.to_h.deep_stringify_keys
      @key_store = Billing::EBICS::KeyStore.new(@credentials)
      super()
      generate
    end

    def filename
      "ebics_initialization_letter_#{safe_filename_part(host_id)}_#{generated_at.to_date.iso8601}.pdf"
    end

    private

    attr_reader :bank_connection, :generated_at, :credentials, :key_store

    def generate
      SECTIONS.each_with_index do |(version, purpose), index|
        start_new_page unless index.zero?
        section(version, purpose)
      end

      page_footer
    end

    def section(version, purpose)
      bounding_box([ 18.mm, bounds.height - 18.mm ], width: bounds.width - 36.mm) do
        title(version, purpose)
        move_down 10.mm
        summary_table(version)
        move_down 10.mm
        certificate_block(version)
        move_down 5.mm
        fingerprint_block(version)
        move_down 10.mm
        confirmation
        move_down 15.mm
        signature_block
      end
    end

    def title(version, purpose)
      text I18n.t("ebics.initialization_letter.sections.#{purpose}", version: version),
        align: :center,
        size: 15,
        style: :bold
    end

    def summary_table(version)
      data = [
        [ label("date"), I18n.l(generated_at.to_date), "Host-ID", host_id ],
        [ label("time"), generated_at.strftime("%H:%M:%S"), "User-ID", credentials.fetch("participant_id") ],
        [ label("recipient"), bank_connection.name.presence || host_id, "Partner-ID", credentials.fetch("client_id") ],
        [ label("organization"), Current.org.name, label("version"), version ]
      ]

      table_width = bounds.width
      table(data, cell_style: { borders: [], padding: [ 2, 2, 2, 0 ], size: 9, leading: 2 }) do
        columns(0).font_style = :bold
        columns(2).font_style = :bold
        columns(0).width = 30.mm
        columns(1).width = (table_width / 2.0) - 30.mm
        columns(2).width = 30.mm
        columns(3).width = (table_width / 2.0) - 30.mm
      end
    end

    def certificate_block(version)
      text label("certificate"), size: 10, style: :bold
      move_down 2.mm
      code_block certificate_for(version).to_pem,
        size: 8.4,
        leading: 0.3,
        padding: [ 5, 6, 5, 6 ]
    end

    def fingerprint_block(version)
      text "#{label("hash")} (SHA-256)", size: 10, style: :bold
      move_down 2.mm
      code_block fingerprint(certificate_for(version)),
        size: 8.4,
        leading: 1.2,
        padding: [ 5, 6, 5, 6 ]
    end

    def confirmation
      text I18n.t("ebics.initialization_letter.confirmation"), size: 9, leading: 2
    end

    def signature_block
      data = [
        [ "_________________________", "_________________________", "_________________________" ],
        [ label("issued_in"), label("name"), label("signature") ]
      ]

      table_width = bounds.width
      table(data, cell_style: { borders: [], align: :center, padding: [ 2, 4, 2, 4 ], size: 9 }) do
        columns(0..2).width = table_width / 3.0
      end
    end

    def code_block(content, size:, leading:, padding:)
      font("Courier") do
        table([ [ content ] ], width: bounds.width, cell_style: {
          background_color: "F7F8FA",
          border_color: "999999",
          border_width: 0.75,
          padding: padding,
          size: size,
          leading: leading
        })
      end
    end

    def page_footer
      number_pages I18n.t("ebics.initialization_letter.page_footer", pages: SECTIONS.size),
        at: [ 18.mm, 9.mm ],
        width: bounds.width - 36.mm,
        align: :center,
        size: 8
    end

    def certificate_for(version)
      @certificates ||= {}
      @certificates[version] ||= Billing::EBICS::Btf::KeyChangeOrderData::CertificateBuilder.new.certificate_for(
        key_store.keys.fetch(version).key,
        version: version,
        client: key_store,
        now: generated_at.utc)
    end

    def fingerprint(certificate)
      Digest::SHA256.hexdigest(certificate.to_der).upcase.scan(/../).join(":")
    end

    def host_id
      credentials.fetch("host_id")
    end

    def label(key)
      I18n.t("ebics.initialization_letter.labels.#{key}")
    end

    def onboarding_certificate_issued_at
      value = bank_connection.status_details.to_h.dig("onboarding", "certificate_issued_at")
      Time.iso8601(value) if value.present?
    end

    def safe_filename_part(value)
      value.to_s.parameterize.presence || "ebics"
    end
  end
end
