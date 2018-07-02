class Ability
  include CanCan::Ability

  def initialize(admin)
    if admin.right? 'readonly'
      can :manage, Admin, id: admin.id
      can :read, available_models
      can :pdf, Invoice
    end
    if admin.right? 'standard'
      can :manage, [Halfday, HalfdayParticipation, Absence, Vegetable, BasketContent] & available_models
      can :create, ActiveAdmin::Comment
      can :update, [Basket, BasketComplement, Delivery]
    end
    if admin.right? 'admin'
      can :manage, HalfdayPreset
      can :create, [BasketComplement, Distribution, Member, Membership, Payment, Invoice] & available_models
      can :update, [Distribution, Member] & available_models
      can :destroy, ActiveAdmin::Comment
      can :destroy, [Member, Membership, Payment], can_destroy?: true
      can :update, [Membership, Payment], can_update?: true
      can :trigger_recurring_billing, Membership
      can :validate, Member, pending?: true
      can :deactivate, Member, can_deactivate?: true
      can :wait, Member, can_wait?: true
      can :send_email, Invoice, can_send_email?: true
      can :cancel, Invoice, can_cancel?: true
    end
    if admin.right? 'superadmin'
      can :manage, [Basket, BasketSize, BasketComplement, Delivery, Distribution, Admin, ACP]
      can :become, Member
    end
  end

  def available_models
    default = [
      Absence,
      Basket,
      BasketSize,
      BasketComplement,
      ActiveAdmin::Page,
      ActiveAdmin::Comment,
      Delivery,
      Distribution,
      Halfday,
      HalfdayParticipation,
      Invoice,
      Member,
      Membership,
      Payment
    ]
    if Current.acp.feature?('basket_content')
      default << BasketContent
      default << Vegetable
    end
    default
  end
end
