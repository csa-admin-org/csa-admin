class Ability
  include CanCan::Ability

  def initialize(admin)
    if admin.email == 'thibaud@thibaud.gg'
      can :manage, :all
    else
      cannot [:manage, :read], Admin
      can [:manage, :read], Admin, id: admin.id
      cannot :manage, [Basket, Delivery]
      can :manage, [HalfdayWork, HalfdayWorkDate, Absence]
      can :create, [Gribouille, Member, Membership, Distribution]
      can :update, [Gribouille, Invoice, Member]
      can :destroy, [Member, Membership], can_destroy?: true
      can :update, Membership, can_update?: true
    end
    cannot :manage, OldInvoice
    cannot [:create, :destroy], Invoice
    can :pdf, Invoice
    can :read, :all
  end
end
