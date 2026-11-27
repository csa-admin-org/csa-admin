# frozen_string_literal: true

module Organization::Logo
  extend ActiveSupport::Concern

  MAX_SIZE = 400.kilobytes
  MIN_DIMENSION = 512
  CONTENT_TYPES = %w[image/png image/jpeg].freeze

  class Processor < HotCell::Client
    hotcell "active_storage"
    operation "organization.logo.process"
  end

  included do
    validate :validate_logo, if: -> { logo.attached? && logo.blob&.new_record? }
  end

  private

  def validate_logo
    validate_logo_content_type
    return if errors[:logo].any?

    validate_logo_size
    validate_logo_dimensions
  rescue CSAAdmin::UnprocessableUpload
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
    result, optimized = process_logo(optimize: errors[:logo].none?)
    width = result[:width]
    height = result[:height]
    unless width.is_a?(Integer) && height.is_a?(Integer) && width.positive? && height.positive?
      errors.add(:logo, :logo_content_type_invalid)
      return
    end

    if width != height
      errors.add(:logo, :logo_not_square)
    elsif width < MIN_DIMENSION
      errors.add(:logo, :logo_too_small)
    elsif optimized
      replace_logo_attachable(optimized)
    end
  end

  def process_logo(optimize:)
    @logo_data = logo_attachable_io.read
    Tempfile.create([ "logo-in", ".bin" ], binmode: true) do |in_tmp|
      in_tmp.write(@logo_data)
      in_tmp.flush

      File.open(in_tmp.path, "rb") do |source|
        if optimize
          process_logo_with_output(source)
        else
          result = Processor.perform_in_hotcell(
            source,
            [],
            content_type: logo.blob.content_type,
            min_dimension: MIN_DIMENSION,
            optimize: false)
          [ result, nil ]
        end
      end
    end
  end

  def process_logo_with_output(source)
    Tempfile.create([ "logo-out", ".bin" ], binmode: true) do |out_tmp|
      result = File.open(out_tmp.path, "wb") do |destination|
        Processor.perform_in_hotcell(
          source,
          destination,
          content_type: logo.blob.content_type,
          min_dimension: MIN_DIMENSION,
          optimize: true)
      end
      optimized =
        if result[:optimized] && File.size(out_tmp.path) < @logo_data.bytesize
          File.binread(out_tmp.path)
        end
      [ result, optimized ]
    end
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
