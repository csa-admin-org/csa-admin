# frozen_string_literal: true

require "kramdown"

class Update
  include Comparable

  Metadata = Data.define(:path, :name, :date)

  def self.all
    metadata.map { |update| new(update.path) }
  end

  def self.unread_count(admin)
    updates = metadata
    return updates.size unless admin.latest_update_read?

    updates.index { |update| update.name == admin.latest_update_read } || 1
  end

  def self.mark_as_read!(admin)
    admin.update!(latest_update_read: metadata.first.name)
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

  class << self
    private

    def metadata
      @metadata_by_locale ||= {}
      @metadata_by_locale[I18n.locale] ||= begin
        path = Rails.root.join("app/views/updates", "*.#{I18n.locale}.md.erb")
        Dir.glob(path).map { |filepath|
          filename = File.basename(filepath, ".md.erb")
          Metadata.new(
            path: filepath,
            name: filename.sub(/\A_\d{8}_/, "").sub(/\.#{I18n.locale}\z/, ""),
            date: Date.parse(filename[/\d+/]))
        }.sort_by(&:date).reverse.freeze
      end
    end
  end

  private

  def filename
    @filename ||= File.basename(@filepath, ".md.erb")
  end
end
