# frozen_string_literal: true

module Organization::Logo
  extend ActiveSupport::Concern

  MAX_SIZE = 400.kilobytes
  MIN_DIMENSION = 512
  CONTENT_TYPES = %w[image/png image/jpeg].freeze

  included do
    validate :validate_logo, if: -> { logo.attached? && logo.blob&.new_record? }
  end

  private

  def validate_logo
    validate_logo_content_type
    return if errors[:logo].any?

    validate_logo_size
    validate_logo_dimensions
  rescue Vips::Error
    errors.add(:logo, :logo_content_type_invalid)
  end

  def validate_logo_content_type
    return if logo.blob.content_type.in?(CONTENT_TYPES)

    errors.add(:logo, :logo_content_type_invalid)
  end

  def validate_logo_size
    return if logo.blob.byte_size <= MAX_SIZE

    errors.add(:logo, :logo_too_heavy)
  end

  def validate_logo_dimensions
    image = logo_image
    if image.width != image.height
      errors.add(:logo, :logo_not_square)
    elsif image.width < MIN_DIMENSION
      errors.add(:logo, :logo_too_small)
    elsif errors[:logo].none?
      optimize_logo!(image)
    end
  end

  def optimize_logo!(image)
    optimized =
      if logo.blob.content_type == "image/png"
        image.pngsave_buffer(compression: 9, palette: true, strip: true)
      else
        image.jpegsave_buffer(Q: 85, strip: true, optimize_coding: true)
      end

    return if optimized.bytesize >= @logo_data.bytesize

    replace_logo_attachable(optimized)
  rescue Vips::Error
    nil # keep original if optimization fails
  end

  def replace_logo_attachable(data)
    attachment_changes["logo"].instance_variable_set(:@attachable, {
      io: StringIO.new(data),
      filename: logo.blob.filename.to_s,
      content_type: logo.blob.content_type
    })
    logo.blob.assign_attributes(
      byte_size: data.bytesize,
      checksum: Digest::MD5.base64digest(data))
  end

  def logo_image
    @logo_data = logo_attachable_io.read
    Vips::Image.new_from_buffer(@logo_data, "")
  end

  def logo_attachable_io
    attachable = attachment_changes["logo"].attachable
    io =
      case attachable
      when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
        attachable.open
      when Hash
        attachable.fetch(:io)
      when File
        attachable
      when Pathname
        attachable.open
      end
    io.rewind
    io
  end
end
