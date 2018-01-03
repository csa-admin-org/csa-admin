class Ability
  include CanCan::Ability

  def initialize(admin)
    case admin.rights
    when 'superadmin'
      can :manage, :all
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
      can :create, [Gribouille, Member, Membership, Distribution, Payment]
      can :update, [Gribouille, Member, Delivery]
      can :validate, Member
      can :remove_from_waiting_list, Member
      can :put_back_to_waiting_list, Member
      can :destroy, [Member, Membership, Payment], can_destroy?: true
      can :update, Membership, can_update?: true
      can :send, Invoice, can_send?: true
      can :cancel, Invoice, can_cancel?: true
      can :pdf, Invoice
      can :read, :all
    when 'standard'
      cannot :manage, :all
      can :manage, [Gribouille, Halfday, HalfdayParticipation, Absence, Vegetable, BasketContent]
      can :create, ActiveAdmin::Comment
      can :update, [Delivery]
      can :pdf, Invoice
      can :read, :all
    when 'readonly'
      cannot :manage, :all
      can :pdf, Invoice
      can :read, :all
    when 'none'
      cannot :manage, :all
    end

    unless admin.superadmin?
      cannot :manage, Admin
      can :manage, Admin, id: admin.id
    end

    cannot :create, Invoice
  end
end
