namespace :memberships do
  desc 'Create next year memprships'
  task seed_next_year: :environment do
    Member.renew_membership.each do |member|
      distribution = member.distribution
      basket = Basket.find_by(name: member.basket.name, year: Date.current.year + 1)
      ActiveRecord.transition do
        member.memberships.create!(
          distribution: distribution,
          basket: basket,
          started_on: (Date.current + 1.year).beginning_of_year,
          ended_on: (Date.current + 1.year).end_of_year,
          annual_halfday_works: member.current_membership&.annual_halfday_works || HalfdayParticipation::MEMBER_PER_YEAR,
          halfday_works_annual_price: member.current_membership&.halfday_works_annual_price || 0)
        member.update!( # out of waiting queue
          waiting_started_at: nil,
          waiting_basket_id: nil,
          waiting_distribution_id: nil)
      end
    end
    # Check custom annual_halfday_works/halfday_works_annual_price after:
    # Membership.future.select { |m| m.halfday_works_annual_price != 0 || m.annual_halfday_works != 2 }.map(&:id).sort
  end
end
