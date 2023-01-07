module Liquidable
  extend ActiveSupport::Concern

  private

  def validate_liquid(attr)
    Current.acp.languages.each do |locale|
      Liquid::Template.parse(send(attr)[locale])
    rescue Liquid::SyntaxError => e
      errors.add("#{attr.to_s.singularize}_#{locale}".to_sym, e.message)
    end
  end

  def validate_html(attr)
    Current.acp.languages.each do |locale|
      doc = Nokogiri::HTML5.fragment(send(attr)[locale], max_errors: 10)
      doc.errors.each do |err|
        errors.add(
          "#{attr.to_s.singularize}_#{locale}".to_sym,
          "HTML error at line #{err.line}: #{err.str1.underscore.humanize}")
      end
    end
  end
end
