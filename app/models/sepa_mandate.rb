# frozen_string_literal: true

class SEPAMandate < ApplicationRecord
  include Sessionable
  include HasIBAN  # provides normalizes :iban and iban_formatted

  SOURCES = %w[self-service admin admin-legacy].freeze

  attr_accessor :sepa_mandate_accepted

  belongs_to :member
  has_many :invoices
  has_one_attached :pdf

  normalizes :umr, with: ->(v) { v.to_s.strip.presence }

  before_validation :set_defaults, on: :create

  validates :iban, :umr, :signed_on, :source, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates_with ::SEPA::IBANValidator
  validates_with ::SEPA::MandateIdentifierValidator, field_name: :umr
  validate :umr_unique_across_members
  validates_acceptance_of :sepa_mandate_accepted, allow_nil: false, if: -> { source == "self-service" }
  validate :pdf_must_be_generated, on: :create

  after_commit :enable_member_sepa!, on: :create
  after_commit :deliver_confirmation_email, on: :create

  scope :recent_first, -> { order(created_at: :desc) }

  def masked_iban
    return unless iban

    head = iban[0, 4]
    tail = iban[-4, 4]
    "#{head} #{"•" * 4} #{"•" * 4} #{tail}"
  end

  # SEPAMandate is append-only: new IBAN submissions always create a new row.
  # Prevent accidental updates to preserve the evidentiary record.
  # Uses before_update instead of readonly? so ActiveStorage can still attach the PDF.
  before_update { raise ActiveRecord::ReadOnlyRecord if changes.any? }

  # Generates and attaches a mandate PDF rendered in the member's locale.
  # Called during validation so the mandate is only saved once the PDF exists.
  def generate_pdf!
    return true if Rails.env.test? && Thread.current[:skip_sepa_mandate_pdf] != false
    return true if pdf.attached?

    I18n.with_locale(member.language) do
      doc = ::PDF::SEPAMandate.new(self)
      pdf.attach(
        io: StringIO.new(doc.render),
        filename: doc.filename,
        content_type: "application/pdf")
    end

    pdf.attached?
  rescue => e
    Rails.error.report(e, context: { sepa_mandate_id: id })
    false
  end

  private

  # Fills in umr, signed_on, and source when not explicitly supplied.
  # Runs before_validation so presence checks pass when the admin form
  # omits these fields.
  def set_defaults
    self.umr = umr.presence || member&.current_sepa_mandate&.umr || member&.id.to_s
    self.signed_on ||= Date.current
    self.source ||= "admin"
  end

  def umr_unique_across_members
    return if umr.blank? || member_id.blank?

    if SEPAMandate.where(umr: umr).where.not(member_id: member_id).exists?
      errors.add(:umr, :taken)
    end
  end

  def pdf_must_be_generated
    return if errors.any?
    return if generate_pdf!

    errors.add(:base, :pdf_generation_failed)
  end

  def enable_member_sepa!
    member&.enable_sepa! if member&.sepa_disabled?
  rescue => e
    Rails.error.report(e, context: { sepa_mandate_id: id, member_id: member_id })
  end

  # Email delivery stays async via MailTemplate/MailDelivery, but only after
  # the mandate and its PDF evidence have been committed successfully.
  def deliver_confirmation_email
    return unless source == "self-service"

    MailTemplate.deliver(:sepa_mandate_confirmation, sepa_mandate: self)
  rescue => e
    Rails.error.report(e, context: { sepa_mandate_id: id })
  end
end
