# frozen_string_literal: true

module PDF
  class Base
    VIEW_PATHS = [ Rails.root.join("app/views") ].freeze
    TEST_LOGO_PNG = Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
    ).freeze

    class ViewContext < ActionView::Base.with_empty_template_cache
      include PDFHelper
    end

    def content_type
      "application/pdf"
    end

    def render
      Sghtmltopdf.render(render_html, **render_options)
    end

    def render_file(path)
      Sghtmltopdf.render_to_file(render_html, path.to_s, **render_options)
    end

    def render_html
      ViewContext
        .with_view_paths(VIEW_PATHS, layout_assigns.merge(view_assigns))
        .render(template: template_path, layout: "layouts/pdf")
    end

    private

    def template_path
      raise NotImplementedError
    end

    def stylesheets
      []
    end

    def view_assigns
      {}
    end

    def title
      nil
    end

    def creation_date
      Time.current
    end

    def layout_assigns
      {
        title: title,
        stylesheets: Array(stylesheets)
      }
    end

    def render_options
      {
        title: title,
        author: Current.org.name,
        creator: Current.org.name,
        creation_date: creation_date
      }.compact
    end

    def org_logo_data_uri(size:)
      @org_logo_data_uris ||= {}
      @org_logo_data_uris[size] ||=
        if Rails.env.test? && Thread.current[:render_pdf_images] != true
          bytes_data_uri(TEST_LOGO_PNG, content_type: "image/png")
        elsif Current.org.logo.attached?
          limit = [ size * 3, size * 3 ]
          blob = Current.org.logo.variant(resize_to_limit: limit).processed
          bytes_data_uri(blob.download, content_type: blob.content_type || "image/png")
        else
          asset_data_uri(Rails.root.join("app/assets/images/logo.png"), content_type: "image/png")
        end
    end

    def asset_data_uri(path, content_type:)
      bytes_data_uri(File.binread(path), content_type: content_type)
    end

    def bytes_data_uri(bytes, content_type:)
      "data:#{content_type};base64,#{[ bytes ].pack("m0")}"
    end
  end
end
