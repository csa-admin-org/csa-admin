# frozen_string_literal: true

module HasAttachments
  extend ActiveSupport::Concern

  MAXIMUM_SIZE = 5.megabytes

  included do
    has_many :attachments, dependent: :destroy, as: :attachable

    accepts_nested_attributes_for :attachments, allow_destroy: true

    validate :attachments_must_not_exceed_maximum_size
    validate :attachments_must_not_be_zero_bytes
  end

  private

  def attachments_must_not_exceed_maximum_size
    if attachments.sum { |a| a.file.byte_size } > MAXIMUM_SIZE
      errors.add(:attachments, :too_large)
    end
  end

  def attachments_must_not_be_zero_bytes
    attachments.each do |attachment|
      if attachment.file.byte_size.zero?
        errors.add(:attachments, :zero_bytes)
      end
    end
  end
end
