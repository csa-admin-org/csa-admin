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

    Summary = Data.define(:generated_at, :host_id, :participant_id, :client_id, :recipient)
    Section = Data.define(:version, :purpose, :title, :certificate_pem, :fingerprint, :page, :total_pages)

    def initialize(bank_connection, generated_at: nil)
      @bank_connection = bank_connection
      @generated_at = (generated_at || onboarding_certificate_issued_at || Time.current).to_time
      @credentials = bank_connection.credentials.to_h.deep_stringify_keys
      @key_store = Billing::EBICS::KeyStore.new(@credentials)
    end

    def filename
      "ebics_initialization_letter_#{safe_filename_part(host_id)}_#{generated_at.to_date.iso8601}.pdf"
    end

    private

    attr_reader :bank_connection, :generated_at, :credentials, :key_store

    def template_path
      "pdfs/ebics_initialization_letters/show"
    end

    def stylesheets
      %w[pdf/ebics_initialization_letter]
    end

    def view_assigns
      {
        summary: build_summary,
        sections: build_sections
      }
    end

    def build_summary
      Summary.new(
        generated_at: generated_at,
        host_id: host_id,
        participant_id: credentials.fetch("participant_id"),
        client_id: credentials.fetch("client_id"),
        recipient: bank_connection.name.presence || host_id
      )
    end

    def build_sections
      SECTIONS.each_with_index.map do |(version, purpose), index|
        certificate = certificate_for(version)
        Section.new(
          version: version,
          purpose: purpose,
          title: I18n.t("ebics.initialization_letter.sections.#{purpose}", version: version),
          certificate_pem: certificate.to_pem.chomp,
          fingerprint: fingerprint(certificate),
          page: index + 1,
          total_pages: SECTIONS.size
        )
      end
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

    def onboarding_certificate_issued_at
      value = bank_connection.status_details.to_h.dig("onboarding", "certificate_issued_at")
      Time.iso8601(value) if value.present?
    end

    def safe_filename_part(value)
      value.to_s.parameterize.presence || "ebics"
    end
  end
end
