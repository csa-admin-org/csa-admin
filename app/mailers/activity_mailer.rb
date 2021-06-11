class ActivityMailer < ApplicationMailer
  include Templatable

  before_action :set_participation

  def participation_reminder_email
    template_mail(@participation.member,
      'member' => Liquid::MemberDrop.new(@participation.member),
      'activity' => Liquid::ActivityDrop.new(@participation.activity),
      'activity_participation' => Liquid::ActivityParticipationDrop.new(@participation))
  end

  def participation_validated_email
    @subject_class = 'notice'
    template_mail(@participation.member,
      'member' => Liquid::MemberDrop.new(@participation.member),
      'activity' => Liquid::ActivityDrop.new(@participation.activity),
      'activity_participation' => Liquid::ActivityParticipationDrop.new(@participation))
  end

  def participation_rejected_email
    @subject_class = 'alert'
    template_mail(@participation.member,
      'member' => Liquid::MemberDrop.new(@participation.member),
      'activity' => Liquid::ActivityDrop.new(@participation.activity),
      'activity_participation' => Liquid::ActivityParticipationDrop.new(@participation))
  end

  private

  def set_participation
    @participation =
      if params[:activity_participation]
        params[:activity_participation]
      else
        participations = ActivityParticipation.where(id: params[:activity_participation_ids])
        ActivityParticipationGroup.new(participations)
      end
  end
end
