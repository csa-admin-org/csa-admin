# frozen_string_literal: true

require "active_storage/hot_cell/server/vips_operation"

class OrganizationLogoOperation < ActiveStorage::HotCell::Server::VipsOperation
  operation "organization.logo.process"

  limits deadline: 10, memory: 1024 * 1024**2, file_size: 2 * 1024**2, open_files: 64

  def perform(inputs, outputs, content_type:, min_dimension:, optimize: false)
    source, = inputs
    destination, = outputs

    image = ::Vips::Image.new_from_file(source.fd_path)
    width = image.width
    height = image.height
    optimized = false

    if optimize && destination && width == height && width >= min_dimension
      optimized = write_optimized(image, destination, content_type)
    end

    copy_original(source, destination) if destination && !optimized

    { width: width, height: height, optimized: optimized }
  end

  private

  def write_optimized(image, destination, content_type)
    data =
      if content_type == "image/png"
        image.pngsave_buffer(compression: 9, palette: true, strip: true)
      else
        image.jpegsave_buffer(Q: 85, strip: true, optimize_coding: true)
      end

    File.binwrite(destination.path, data)
    true
  rescue ::Vips::Error
    false
  end

  def copy_original(source, destination)
    File.open(source.fd_path, "rb") { |io| IO.copy_stream(io, destination.path) }
  end
end
