class Ability
  include CanCan::Ability

  def initialize(admin)
    case admin.rights
    when 'superadmin'
      can :manage, :all
      cannot :destroy, Invoice
      can :destroy, Invoice, can_destroy?: true
      can :pdf, Invoice
    when 'admin'
      cannot :manage, [BasketSize, Delivery]
      can :manage, [Halfday, HalfdayParticipation, Absence]
      can :create, [Gribouille, Member, Membership, Distribution]
      can :update, [Gribouille, Invoice, Member, Delivery]
      can :validate, Member
      can :remove_from_waiting_list, Member
      can :put_back_to_waiting_list, Member
      can :destroy, [Member, Membership], can_destroy?: true
      can :update, Membership, can_update?: true
      can :pdf, Invoice
      can :read, :all
    when 'standard'
      cannot :manage, :all
      can :manage, [Gribouille, Halfday, HalfdayParticipation, Absence, Vegetable, BasketContent]
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

    cannot :manage, OldInvoice
    cannot :create, Invoice
  end
end
