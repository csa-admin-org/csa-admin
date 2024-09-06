# frozen_string_literal: true

class Update
  include Comparable

  TRANSLATED_SINCE = Date.new(2024, 6, 1)

  def self.all
    # TODO: Remove this line when all latest updates are translated
    path = Rails.root.join("app/views/updates", "*.md.erb")
    all = Dir.glob(path).map { |path| new(path) }
    all.select! { |update| update.date <= TRANSLATED_SINCE }

    path = Rails.root.join("app/views/updates", "*.#{I18n.locale}.md.erb")
    all += Dir.glob(path).map { |path| new(path) }
    all.sort.reverse
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

  def body(context)
    @body ||= begin
      body = File.read(@filepath)
      result = ERB.new(body).result(context)
      Kramdown::Document.new(result).to_html.html_safe
    end
  end

  def name
    @name ||= filename.sub(/\A_\d{8}_/, "").sub(/\.#{I18n.locale}\z/, "")
  end

  def date
    @date ||= Date.parse(filename[/\d+/])
  end

  def <=>(other)
    date <=> other.date
  end

  private

  def filename
    @filename ||= File.basename(@filepath, ".md.erb")
  end
end
