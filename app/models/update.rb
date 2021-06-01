class Update
  include Comparable

  def self.all
    @all ||= begin
      path = Rails.root.join('updates', '*.md')
      Dir.glob(path).map { |path|
        new(path)
      }.sort.reverse
    end
  end

  def self.unread_count(admin)
    return all.size unless admin.latest_update_read?

    all.map(&:name).index(admin.latest_update_read)
  end

  def self.mark_as_read!(admin)
    admin.update!(latest_update_read: all.first.name)
  end

  def initialize(filepath)
    @filepath = filepath
  end

  def content
    markdown = File.read(@filepath)
    Kramdown::Document.new(markdown).to_html.html_safe
  end

  def name
    @name ||= filename.sub(/\d{8}_/, '')
  end

  def date
    @date ||= Date.parse(filename)
  end

  def <=>(other)
    date <=> other.date
  end

  private

  def filename
    @filename ||= File.basename(@filepath, '.md')
  end
end
