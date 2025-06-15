# frozen_string_literal: true

class Ability
  include CanCan::Ability

  MODELS_MAPPING = {
    delivery: [ Delivery, DeliveryCycle ],
    depot: [ Depot, DepotGroup ],
    membership: [ Membership, Basket, BasketShift ],
    billing: [ Invoice, Payment ],
    activity: [ Activity, ActivityParticipation, ActivityPreset ],
    basket_content: [ BasketContent, BasketContent::Product ],
    shop: [
      Shop::Order,
      Shop::OrderItem,
      Shop::Producer,
      Shop::Product,
      Shop::SpecialDelivery,
      Shop::Tag
    ],
    newsletter: [
      Newsletter,
      Newsletter::Delivery,
      Newsletter::Segment,
      Newsletter::Template
    ]
  }

  def initialize(admin)
    can :read, [ ActiveAdmin::Page, ActiveAdmin::Comment, Audit ]
    can :read, available_models
    can :pdf, Invoice
    can :sepa_pain, Invoice
    can :sepa_pain_all, Invoice

    writable_models = []

    if admin.permission.can_write?(:organization)
      can :read, Organization
      can :update, Organization, id: Current.org.id
    end

    if admin.permission.can_write?(:admin)
      can :manage, Admin
      cannot :destroy, Admin, id: admin.id
    end
    can :update, Admin, id: admin.id

    if admin.permission.can_write?(:basket_complement)
      writable_models += models_for(:basket_complement)
    end

    if admin.permission.can_write?(:basket_size)
      writable_models += models_for(:basket_size)
    end

    if admin.permission.can_write?(:comment)
      can :manage, ActiveAdmin::Comment
    end
    can :create, ActiveAdmin::Comment
    can :manage, ActiveAdmin::Comment, author: admin

    if admin.permission.can_write?(:delivery)
      writable_models += models_for(:delivery)
    end

    if admin.permission.can_write?(:permission)
      writable_models += models_for(:permission)
    end

    if admin.permission.can_write?(:mail_template)
      writable_models += models_for(:mail_template)
      can :preview, MailTemplate
    end

    if admin.permission.can_write?(:member)
      writable_models += models_for(:member)

      can :become, Member
      can :validate, Member, pending?: true
      can :deactivate, Member, can_deactivate?: true
      can :wait, Member, can_wait?: true
    end

    if admin.permission.can_write?(:membership)
      writable_models += models_for(:membership)

      can :renew_all, Membership
      can :open_renewal_all, Membership
      can :open_renewal, Membership, can_open_renewal?: true
      can :clear_activity_participations_demanded, Membership, can_clear_activity_participations_demanded?: true
      can :mark_renewal_as_pending, Membership
      can :future_billing, Membership
      can :renew, Membership
      can :cancel, Membership
    end

    if admin.permission.can_write?(:billing)
      writable_models += models_for(:billing)

      can :recurring_billing, Member
      can :force_share_billing, Member
      can :send_email, Invoice, can_send_email?: true
      can :mark_as_sent, Invoice, can_be_mark_as_sent?: true
      can :cancel, Invoice, can_cancel?: true
      can :import, Payment
      can :invoice_all, ActivityParticipation
      can :ignore, Payment, can_ignore?: true
      can :unignore, Payment, can_unignore?: true
    end

    if admin.permission.can_write?(:depot)
      writable_models += models_for(:depot)
    end

    if admin.permission.can_write?(:announcement)
      writable_models += models_for(:announcement)
    end

    if admin.permission.can_write?(:absence)
      writable_models += models_for(:absence)
    end

    if admin.permission.can_write?(:activity)
      writable_models += models_for(:activity)
    end

    if admin.permission.can_write?(:activity_participation)
      can :validate, ActivityParticipation, can_validate?: true
      can :reject, ActivityParticipation, can_reject?: true
    end

    if admin.permission.can_write?(:basket_content)
      writable_models += models_for(:basket_content)
    end

    if admin.permission.can_write?(:shop)
      writable_models += models_for(:shop)

      can :invoice, Shop::Order, can_invoice?: true
      can :cancel, Shop::Order, can_cancel?: true
    end

    if admin.permission.can_write?(:newsletter)
      writable_models += models_for(:newsletter)

      can :preview, [ Newsletter, Newsletter::Template ]
      can :unschedule, Newsletter
      can :send_email, Newsletter, can_send_email?: true
      can :send_single_email, Newsletter
    end

    if admin.master?
      can :manage, Session
    end

    can :create, writable_models
    can :update, writable_models, can_update?: true
    can :destroy, writable_models, can_destroy?: true
    can :batch_action, writable_models
  end

  private

  def available_models
    @available_models ||= Permission.features.map { |f| models_mapping(f) }.flatten
  end

  def models_for(feature)
    models_mapping(feature) & available_models
  end

  def models_mapping(feature)
    MODELS_MAPPING[feature] || [ feature.to_s.classify.constantize ]
  end
end
