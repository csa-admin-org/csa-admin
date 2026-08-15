# frozen_string_literal: true

class Demo::Registration
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :message, :string

  attr_accessor :request
  attr_reader :session

  validate :admin_must_be_valid

  def save
    return false unless valid?

    admin = create_admin!
    @session = create_session!(admin)
    send_invitation_email!(admin)
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
      permission: Permission.superadmin,
      demo_message: message.presence)
  end

  def create_session!(admin)
    Session.create!(admin_email: admin.email, request: request)
  end

  def send_invitation_email!(admin)
    invite_session = create_session!(admin)
    action_url = Rails.application.routes.url_helpers.session_url(
      invite_session.generate_token_for(:demo_invite),
      host: Tenant.admin_host)
    AdminMailer.with(
      admin: admin,
      action_url: action_url
    ).invitation_email.deliver_later(queue: :critical)
  end
end
