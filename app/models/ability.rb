class Ability
  include CanCan::Ability

  def initialize(admin)
    case admin.rights
    when 'superadmin'
      can :manage, available_models + [Admin, ACP]
      cannot :send, Invoice
      can :send, Invoice, can_send?: true
      cannot :cancel, Invoice
      can :cancel, Invoice, can_cancel?: true
      can :pdf, Invoice
      cannot :destroy, [Member, Invoice, Payment]
      can :destroy, [Member, Payment], can_destroy?: true
    when 'admin'
      cannot :manage, [BasketSize, Delivery]
      can :manage, [Halfday, HalfdayParticipation, Absence, ActiveAdmin::Comment]
      can :create, available_models & [Gribouille, Member, Membership, Distribution, Payment]
      can :update, available_models & [Gribouille, Member, Delivery, Distribution]
      can :validate, Member
      can :remove_from_waiting_list, Member
      can :put_back_to_waiting_list, Member
      can :destroy, [Member, Membership, Payment], can_destroy?: true
      can :update, Membership, can_update?: true
      can :send, Invoice, can_send?: true
      can :cancel, Invoice, can_cancel?: true
      can :pdf, Invoice
      can :read, available_models
    when 'standard'
      cannot :manage, :all
      can :manage, available_models & [Gribouille, Halfday, HalfdayParticipation, Absence, Vegetable, BasketContent]
      can :create, ActiveAdmin::Comment
      can :update, [Delivery]
      can :pdf, Invoice
      can :read, available_models
    when 'readonly'
      cannot :manage, :all
      can :pdf, Invoice
      can :read, available_models
    when 'none'
      cannot :manage, :all
    end

    unless admin.superadmin?
      cannot :manage, Admin
      can :manage, Admin, id: admin.id
    end

    cannot :create, Invoice
  end

  def available_models
    default = [
      Absence,
      Basket,
      BasketSize,
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
    if Current.acp.feature?('gribouille')
      default << Gribouille
    end
    default
  end
end
