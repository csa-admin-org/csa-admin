class Ability
  include CanCan::Ability

  def initialize(admin)
    if admin.right? 'readonly'
      can :manage, Admin, id: admin.id
      can :read, available_models
      can :pdf, Invoice
    end
    if admin.right? 'standard'
      can :manage, [Gribouille, Halfday, HalfdayParticipation, Absence, Vegetable, BasketContent] & available_models
      can :create, ActiveAdmin::Comment
      can :update, [Basket, BasketComplement, Delivery]
    end
    if admin.right? 'admin'
      can :create, [BasketComplement, Distribution, Member, Membership, Payment] & available_models
      can :update, [Distribution, Member] & available_models
      can :destroy, ActiveAdmin::Comment
      can :destroy, [Member, Membership, Payment], can_destroy?: true
      can :update, Membership, can_update?: true
      can :validate, Member, pending?: true
      can :create_invoice, Member, billable?: true
      can :remove_from_waiting_list, Member, waiting?: true
      can :put_back_to_waiting_list, Member, inactive?: true
      can :send_email, Invoice, can_send_email?: true
      can :cancel, Invoice, can_cancel?: true
    end
    if admin.right? 'superadmin'
      can :manage, [Basket, BasketSize, BasketComplement, Delivery, Distribution, Admin, ACP]
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
    if Current.acp.feature?('gribouille')
      default << Gribouille
    end
    default
  end
end
