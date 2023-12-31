class Handbook
  include Comparable

  DIR_PATH = "app/views/handbook"
  attr_reader :name

  def self.all(context)
    path = Rails.root.join(DIR_PATH, "*.md.erb")
    Dir.glob(path).map { |path|
      name = File.basename(path, ".md.erb")
      new(name, context)
    }.sort
  end

  def initialize(name, context)
    @name = name
    @context = context
  end

  def filepath
    Rails.root.join(DIR_PATH, "#{name}.md.erb")
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

  def <=>(other)
    title <=> other.title
  end
end
