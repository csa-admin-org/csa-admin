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
    when :member_state; Member.model_name.human(count: 2)
    when :activity_state; activities_human_name
    end
  end
end
