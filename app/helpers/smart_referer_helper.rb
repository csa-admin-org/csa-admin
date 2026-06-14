# frozen_string_literal: true

module SmartRefererHelper
  def smart_referer(attr)
    params[attr].presence || referer_filter(attr) || smart_referer_context[attr.to_s]
  end

  private

  def referer_filter(attr)
    return unless request&.referer

    query = URI(request.referer).query
    Rack::Utils.parse_nested_query(query).dig("q", "#{attr}_eq")
  rescue URI::InvalidURIError
    nil
  end
end
