class Liquid::DataPreview
  def self.for(mail_template, random: nil)
    new(
      mail_template.mailer_preview,
      mail_template.email_method,
      random || mail_template.updated_at.to_i
    ).data
  end

  def initialize(mailer_preview, email_method, random)
    @mailer_preview = mailer_preview.new(random: random)
    @email_method = email_method
  end

  def data
    params = @mailer_preview.send("#{@email_method}_params")
    params[:acp] = Current.acp
    params.map { |key, object|
      drop_class = drop_class(key)
      if drop_class && object
        data =
          if object.is_a?(Array)
            object.map { |o| drop_hash(drop_class.new(o)) }
          else
            drop_hash(drop_class.new(object))
          end
        [key, data]
      else
        [key, object]
      end
    }.sort.to_h.deep_stringify_keys!
  end

  private

  def drop_hash(drop)
    invokable_methods(drop).map { |method|
      value = drop.send(method)
      [method, handle_value(value)]
    }.sort.to_h
  end

  def drop_class(key)
    drop_class = "liquid/#{key}_drop".classify
    if Object.const_defined?(drop_class)
      drop_class.constantize
    else
      case key
      when /.*_activities\z/
        Liquid::ActivityDrop
      when /.*_activity_participations\z/
        Liquid::ActivityParticipationDrop
      end
    end
  end

  def handle_value(value)
    if value.class < Liquid::Drop
      drop_hash(value)
    elsif value.is_a?(Array)
      value.map! { |v| handle_value(v) }
    else
      value
    end
  end

  def invokable_methods(drop)
    methods = drop.class.invokable_methods
    methods -= %w[to_liquid]
    unless Current.acp.feature?(:activity)
      methods -= %w[
        activity_phone
        activities_url
        activity_participations_demanded_count
        activity_participations_accepted_count
        activity_participations_missing_count
      ]
    end
    unless Current.acp.feature?(:basket_content)
      methods -= %w[contents]
    end
    methods
  end
end
