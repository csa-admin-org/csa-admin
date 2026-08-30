# frozen_string_literal: true

require "kramdown"
require "nokogiri"

# PORO representing a handbook page — static Markdown/ERB documentation
# embedded in the app at /handbook/:id.
#
# Two usage modes:
#   1. Instance mode: renders a single page via ERB + Kramdown,
#      requires a controller binding for helpers like Current.org, feature?().
#   2. Class-level search (via Handbook::Search concern): parses raw markdown
#      with regex to extract headings, resolving only safe ERB human-name calls.
#      Results are cached per locale (invalidated on app restart).
#
# Country-specific content:
#   Wrap sections with <!-- country:XX --> / <!-- /country:XX --> markers.
#   These blocks are stripped for non-matching orgs in both rendering and search.
class Handbook
  include Comparable
  include Search

  DIR_PATH = "app/views/handbook"

  COUNTRY_SECTION_REGEX = /<!-- country:(!?\w+) -->\n?(.*?)<!-- \/country:\1 -->\n?/m
  DEMO_ONLY_PAGES = %i[setup].freeze

  attr_reader :name

  def self.all(context, locale = I18n.locale)
    path = Rails.root.join(DIR_PATH, "*.#{locale}.md.erb")
    Dir.glob(path).filter_map { |path|
      name = File.basename(path, ".#{locale}.md.erb")
      handbook = new(name, context, locale)
      handbook if handbook.content?
    }.sort
  end

  def self.filter_country_sections(text, country_code = Current.org.country_code)
    text.gsub(COUNTRY_SECTION_REGEX) do
      code = $1
      if code.start_with?("!")
        code.delete_prefix("!") != country_code ? $2 : ""
      else
        code == country_code ? $2 : ""
      end
    end
  end

  def initialize(name, context, locale = I18n.locale)
    @name = name
    @context = context
    @locale = locale
  end

  def filepath
    Rails.root.join(DIR_PATH, "#{name}.#{@locale}.md.erb")
  end

  def body
    @body ||= doc.children
      .reject { |node| node.element? && node.name == "h1" }
      .map(&:to_html)
      .join
      .html_safe
  end

  def doc
    @doc ||= begin
      markdown = File.read(filepath)
      markdown = self.class.filter_country_sections(markdown)
      html = Kramdown::Document.new(ERB.new(markdown).result(@context)).to_html
      Nokogiri::HTML::DocumentFragment.parse(html)
    end
  end

  def title
    @title ||= doc.at_css("h1")&.text
  end

  def subtitles
    @subtitles ||= doc.css("h2").filter_map { |heading|
      [ heading.text, heading[:id] ] if heading[:id].present?
    }
  end

  def restricted?
    name.to_sym.in?(Organization.restricted_features)
  end

  def demo_only?
    name.to_sym.in?(DEMO_ONLY_PAGES)
  end

  # True when the page has visible content after country-section filtering.
  # Cheaper than rendering body — reads the raw file and checks for an H1.
  def content?
    raw = File.read(filepath)
    filtered = self.class.filter_country_sections(raw)
    filtered.match?(/^#\s+.+$/)
  end

  def <=>(other)
    pin = pinned_rank <=> other.pinned_rank
    return pin unless pin.zero?

    I18n.transliterate(title) <=> I18n.transliterate(other.title)
  end

  def pinned_rank
    name == "getting_started" ? 0 : 1
  end
  protected :pinned_rank
end
