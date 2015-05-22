class Ability
  include CanCan::Ability

  def initialize(admin)
    can :read, :all
    if admin.email == 'thibaud@thibaud.gg'
      can :manage, :all
    else
      cannot [:manage, :read], Admin
      can [:manage, :read], Admin, id: admin.id
      cannot :manage, [Basket, Delivery]
      can :manage, [HalfdayWork, HalfdayWorkDate, Absence]
      can :create, [Member, Membership, Distribution]
      can :update, [Member, Distribution]
      can :destroy, [Member, Membership], can_destroy?: true
      can :update, Membership, can_update?: true
    end
    cannot :manage, [Invoice]
  end
end
