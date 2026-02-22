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
#      with regex to extract headings. No ERB rendering needed because
#      h1/h2 lines are plain text. Results are cached per locale
#      (invalidated on app restart).
class Handbook
  include Comparable
  include Search

  DIR_PATH = "app/views/handbook"

  attr_reader :name

  def self.all(context, locale = I18n.locale)
    path = Rails.root.join(DIR_PATH, "*.#{locale}.md.erb")
    Dir.glob(path).map { |path|
      name = File.basename(path, ".#{locale}.md.erb")
      new(name, context, locale)
    }.sort
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
    @body ||= begin
      body = File.read(filepath)
      result = ERB.new(body).result(@context)
      Kramdown::Document.new(result).to_html.html_safe
    end
  end

  def doc
    @doc ||= Nokogiri::HTML::DocumentFragment.parse(body)
  end

  def title
    @title ||= doc.css("h1").map(&:text).first
  end

  def subtitles
    @subtitles ||= doc.css("h2").map { |h2| [ h2.text, h2[:id] ] }
  end

  def restricted?
    name.to_sym.in?(Organization.restricted_features)
  end

  def <=>(other)
    I18n.transliterate(title) <=> I18n.transliterate(other.title)
  end
end
