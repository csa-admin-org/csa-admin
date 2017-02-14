class Ability
  include CanCan::Ability

  def initialize(admin)
    if admin.email == 'thibaud@thibaud.gg'
      can :manage, :all
      cannot :destroy, Invoice
      can :destroy, Invoice, can_destroy?: true
    elsif admin.email.in? %w[chantalgraef@gmail.com raphael.coquoz@bluewin.ch]
      cannot [:manage, :read], Admin
      can [:manage, :read], Admin, id: admin.id
      cannot :manage, [Basket, Delivery]
      can :manage, [Halfday, HalfdayParticipation, Absence]
      can :create, [Gribouille, Member, Membership, Distribution]
      can :update, [Gribouille, Invoice, Member]
      can :destroy, [Member, Membership], can_destroy?: true
      can :update, Membership, can_update?: true
    else
      cannot :manage, :all
      can :manage, [Gribouille, Halfday, HalfdayParticipation, Absence, Vegetable, BasketContent]
    end
    cannot :manage, OldInvoice
    cannot :create, Invoice
    can :pdf, Invoice
    can :read, :all
  end
end
