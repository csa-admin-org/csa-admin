module BulkActivityIdsInsert
  extend ActiveSupport::Concern

  included do
    attribute :activity_ids, :integer, array: true

    with_options if: :activity do
      validates :activity_ids, absence: true
    end
    with_options unless: :activity do
      validates :activity_ids, presence: true
    end
  end

  def save(*args)
    if activity
      super
    elsif all_valid?
      @participations.each(&:save)
    else
      @participations.each do |participation|
        participation.errors.messages.each do |attr, message|
          errors.add attr, message.join(', ')
        end
      end
      false
    end
  end

  def date
    activity&.date || @participations&.first&.activity&.date
  end

  def activity_ids=(ids)
    return unless ids

    ids = ids.map(&:presence).compact.map(&:to_i)
    if ids.one?
      self.activity_id = ids.first
    else
      @activity_ids = ids
    end
  end

  private

  def all_valid?
    @participations = activity_ids.map do |activity_id|
      part = self.class.new(attributes)
      part.activity_id = activity_id
      part.carpooling = @carpooling ? '1' : nil
      part
    end
    @participations.any? && @participations.all?(&:valid?)
  end
end
