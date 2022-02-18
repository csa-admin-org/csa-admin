class Ability
  include CanCan::Ability

  def initialize(admin)
    can :pdf, Invoice if Rails.env.development?

    if admin.right? 'readonly'
      can :manage, Admin, id: admin.id
      can :read, available_models
      can :read, MailTemplate
      can :pdf, Invoice
    end
    if admin.right? 'standard'
      can :manage, [ActivityParticipation, Absence, Announcement, Vegetable, BasketContent] & available_models
      can :create, [Activity, ActiveAdmin::Comment]
      can :update, [Activity, BasketComplement]
      can :update, [Delivery, Basket], can_update?: true
      can :destroy, Activity, can_destroy?: true
    end
    if admin.right? 'admin'
      can :read, Admin
      can :create, Delivery
      can :manage, ActivityPreset if Current.acp.feature?('activity')
      can :create, group_buying_models & available_models
      can :update, group_buying_models & available_models
      can :destroy, group_buying_models & available_models, can_destroy?: true
      can :cancel, [GroupBuying::Order] & available_models, can_cancel?: true
      can :create, shop_models & available_models
      can :update, shop_models & available_models, can_update?: true
      can :destroy, shop_models & available_models, can_destroy?: true
      can :invoice, [Shop::Order] & available_models, can_invoice?: true
      can :cancel, [Shop::Order] & available_models, can_cancel?: true
      can :create, [BasketComplement, Depot, Member, Membership, Payment, Invoice] & available_models
      can :update, [Depot, Member] & available_models
      can :destroy, ActiveAdmin::Comment
      can :destroy, [Member, Membership, Payment, Invoice, Delivery], can_destroy?: true
      can :update, [Membership, Payment], can_update?: true
      can :force_recurring_billing, Member
      can :renew_all, Membership
      can :open_renewal_all, Membership
      can :open_renewal, Membership, can_send_email?: true
      can :enable_renewal, Membership
      can :renew, Membership
      can :cancel, Membership
      can :validate, Member, pending?: true
      can :deactivate, Member, can_deactivate?: true
      can :wait, Member, can_wait?: true
      can :send_email, Invoice, can_send_email?: true
      can :cancel, Invoice, can_cancel?: true
      can :import, Payment
    end
    if admin.right? 'superadmin'
      can :manage, [Admin, ACP, MailTemplate]
      sensible_models = [BasketSize, BasketComplement, Depot, DeliveriesCycle]
      can :create, sensible_models
      can :update, sensible_models
      can :destroy, sensible_models, can_destroy?: true
      can :become, Member
    end
    # if admin.master?
    # end
  end

  def available_models
    default = [
      Announcement,
      Basket,
      BasketSize,
      BasketComplement,
      ActiveAdmin::Page,
      ActiveAdmin::Comment,
      Delivery,
      DeliveriesCycle,
      Depot,
      Handbook,
      Invoice,
      Member,
      Membership,
      Payment
    ]
    if Current.acp.feature?('absence')
      default << Absence
    end
    if Current.acp.feature?('activity')
      default << Activity
      default << ActivityParticipation
    end
    if Current.acp.feature?('basket_content')
      default << BasketContent
      default << Vegetable
    end
    if Current.acp.feature?('group_buying')
      default += group_buying_models
    end
    if Current.acp.feature?(:shop)
      default += shop_models
    end
    default
  end

  def group_buying_models
    [
      GroupBuying::Delivery,
      GroupBuying::Producer,
      GroupBuying::Product,
      GroupBuying::Order
    ]
  end

  def shop_models
    [
      Shop::Order,
      Shop::OrderItem,
      Shop::Producer,
      Shop::Product,
      Shop::Tag
    ]
  end
end
