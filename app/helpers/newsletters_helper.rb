module NewslettersHelper
  def newsletter_audience_collection
    Newsletter::Audience.segments.map { |key, segments|
      [
        audience_name(key),
        segments.map { |s| [s.name, s.id] }
      ]
    }.to_h
  end

  def audience_name(key)
    case key
    when :basket_size_id; BasketSize.model_name.human
    when :basket_complement_id; BasketComplement.model_name.human
    when :depot_id; Depot.model_name.human
    when :delivery_id; Delivery.model_name.human
    when :member_state; Member.model_name.human(count: 2)
    when :activity_state; activities_human_name
    when :activity_id; Activity.model_name.human
    when :shop_delivery_gid
      Shop::Order.model_name.human(count: 2) + " (#{t('shop.title')})"
    end
  end

  def ellipsisize(email)
    return unless email

    email.split('@').map { |part|
      case part.length
      when 0..5
        part.gsub(%r{(.).+(.)}, '\1...\2')
      when 5..8
        part.gsub(%r{(.{2}).{2,}(.{2})}, '\1...\2')
      else
        part.gsub(%r{(.{3}).{3,}(.{3})}, '\1...\2')
      end
    }.join('@')
  end
end
