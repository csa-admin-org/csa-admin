namespace :halfdays do
  desc 'Send coming halfday emails'
  task send_coming_emails: :environment do
    HalfdayParticipation.send_coming_mails
    p 'Coming halfday emails sent.'
  end

  desc 'Charge halfday work that have not been done'
  task charge_missing: :environment do
    Member.all.select { |m| m.remaining_halfday_works.positive? }.each do |member|
      missing_halfdays = member.remaining_halfday_works
      price = missing_halfdays * HalfdayParticipation::PRICE
      membership = member.current_year_memberships.last
      p "Member #{member.id}, Facturé #{missing_halfdays} demi-journée(s) de travail à #{price}"
      membership.decrement(:annual_halfday_works, missing_halfdays)
      membership.increment(:halfday_works_annual_price, price)
      membership.add_note("#{Date.current}: Facturé #{missing_halfdays} demi-journée(s) de travail à #{price}.-")
      membership.save!
    end
  end
end
