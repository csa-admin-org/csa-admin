# frozen_string_literal: true

module HasAttachments
  extend ActiveSupport::Concern

  MAXIMUM_SIZE = 5.megabytes

  included do
    has_many :attachments, dependent: :destroy, as: :attachable

    accepts_nested_attributes_for :attachments, allow_destroy: true

    validate :attachments_must_not_exceed_maximum_size
  end

  private

  def attachments_must_not_exceed_maximum_size
    if attachments.sum { |a| a.file.byte_size } > MAXIMUM_SIZE
      errors.add(:attachments, :too_large)
    end
  end
end
