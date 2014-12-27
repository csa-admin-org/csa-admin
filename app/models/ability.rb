class Ability
  include CanCan::Ability

  def initialize(admin)
    if admin.email == 'thibaud@thibaud.gg'
      can :manage, :all
    else
      cannot [:manage, :read], Admin
      can [:manage, :read], Admin, id: admin.id
      cannot :manage, [Basket, Distribution, Delivery]
      can :create, [Member, Membership, Distribution]
      can :destroy, [Member, Membership], can_destroy?: true
      can :update, Membership, can_update?: true
      can :read, :all
      if admin.email == 'chantalgraef@gmail.com'
        cannot :read, HalfdayWork
      else
        can :update, Distribution
      end
    end
  end
end
