# frozen_string_literal: true

class Demo::Registration
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :note, :string

  attr_accessor :request

  validate :admin_must_be_valid

  def save
    return false unless valid?

    admin = create_admin!
    send_invitation_email!(admin)
    send_notification_email!(admin)
    true
  end

  private

  def admin_must_be_valid
    return if build_admin.valid?

    build_admin.errors.each do |error|
      next unless %i[name email].include?(error.attribute)

      errors.add(error.attribute, error.type, **error.options)
    end
  end

  def create_admin!
    build_admin.save!
    build_admin
  end

  def build_admin
    @build_admin ||= Admin.new(
      name: name,
      email: email,
      language: Tenant.demo_language,
      permission: Permission.superadmin)
  end

  def send_invitation_email!(admin)
    session = Session.create!(admin_email: admin.email, request: request)
    action_url = Rails.application.routes.url_helpers.session_url(
      session.generate_token_for(:redeem),
      host: Tenant.admin_host)
    AdminMailer.with(
      admin: admin,
      action_url: action_url
    ).invitation_email.deliver_later
  end

  def send_notification_email!(admin)
    AdminMailer.with(
      admin: admin,
      note: note.presence,
      tenant: Tenant.current
    ).demo_registration_notification_email.deliver_later
  end
end
