class Ability
  include CanCan::Ability

  def initialize(admin)
    if admin.email == 'thibaud@thibaud.gg'
      can :manage, :all
    elsif admin.email.in? %w[chantalgraef@gmail.com raphael.coquoz@bluewin.ch]
      cannot [:manage, :read], Admin
      can [:manage, :read], Admin, id: admin.id
      cannot :manage, [Basket, Delivery]
      can :manage, [HalfdayWork, HalfdayWorkDate, Absence]
      can :create, [Gribouille, Member, Membership, Distribution]
      can :update, [Gribouille, Invoice, Member]
      can :destroy, [Member, Membership], can_destroy?: true
      can :update, Membership, can_update?: true
    else
      cannot :manage, :all
      can :manage, [Gribouille, HalfdayWork, HalfdayWorkDate, Absence, Vegetable, BasketContent]
    end
    cannot :manage, OldInvoice
    cannot [:create, :destroy], Invoice
    can :pdf, Invoice
    can :read, :all
  end
end
