class ActivityMailer < ApplicationMailer
  include Templatable

  def participation_reminder_email
    activity_participation = params[:activity_participation]
    activity = activity_participation.activity
    member = activity_participation.member
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'activity' => Liquid::ActivityDrop.new(activity),
      'activity_participation' => Liquid::ActivityParticipationDrop.new(activity_participation))
  end

  def participation_validated_email
    activity_participation = params[:activity_participation]
    activity = activity_participation.activity
    member = activity_participation.member
    @subject_class = 'notice'
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'activity' => Liquid::ActivityDrop.new(activity),
      'activity_participation' => Liquid::ActivityParticipationDrop.new(activity_participation))
  end

  def participation_rejected_email
    activity_participation = params[:activity_participation]
    activity = activity_participation.activity
    member = activity_participation.member
    @subject_class = 'alert'
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'activity' => Liquid::ActivityDrop.new(activity),
      'activity_participation' => Liquid::ActivityParticipationDrop.new(activity_participation))
  end
end
