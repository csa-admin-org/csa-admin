# lib/tasks/svg_to_png.rake
require "image_processing/vips"

namespace :simpleicons do
  desc "Convert SVG icons to PNG with specific color fill and ensure minimum size"
  task svg_to_png: :environment do
    require "fileutils"

    svg_dir = Rails.root.join("app/assets/svg/icons/simpleicons")
    output_dir = Rails.root.join("app/assets/images/simpleicons")
    FileUtils.mkdir_p(output_dir.to_s)

    min_size = 20 * 3
    color_fill = "#AAAAAA"

    Dir.glob(svg_dir.join("*.svg")).each do |svg_file_path|
      svg_file = svg_file_path.to_s
      file_name = File.basename(svg_file, ".svg")
      png_file = output_dir.join("#{file_name}.png").to_s

      begin
        svg_content = File.read(svg_file)

        # Ensure the color fill is applied to all paths and the SVG itself
        svg_with_fill = svg_content.gsub("<svg", "<svg fill=\"#{color_fill}\"")
        svg_with_fill = svg_with_fill.gsub(/<path([^>]*)>/, "<path fill=\"#{color_fill}\" \\1>")

        # Parse the viewBox to calculate scaling
        viewbox_match = svg_content.match(/viewBox=["']([\d\s\.]+)["']/)
        if viewbox_match
          _, _, original_width, original_height = viewbox_match[1].split.map(&:to_f)
        else
          original_width = original_height = min_size # Default to small icon size
        end

        # Calculate scale factor to ensure minimum size
        scale_factor = [ min_size / original_width, min_size / original_height ].max

        # Compute new dimensions
        target_width = (original_width * scale_factor).ceil
        target_height = (original_height * scale_factor).ceil

        # Inject explicit width and height into the SVG content
        svg_with_dimensions = svg_with_fill.gsub("<svg", "<svg width=\"#{target_width}\" height=\"#{target_height}\"")

        # Write modified SVG to a temporary file
        temp_svg_file = Tempfile.new([ "icon", ".svg" ])
        temp_svg_file.write(svg_with_dimensions)
        temp_svg_file.close

        # Convert the SVG to PNG using the scaled dimensions
        ImageProcessing::Vips
          .source(temp_svg_file.path)
          .convert("png")
          .call(destination: png_file)

        puts "Converted #{file_name} (#{target_width}x#{target_height}, #{color_fill})"
      rescue => e
        puts "Failed to convert #{file_name}: #{e.message}"
      ensure
        temp_svg_file&.unlink # Clean up the temporary file
      end
    end
  end
end
