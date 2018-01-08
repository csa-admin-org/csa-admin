namespace :halfdays do
  desc 'Send coming halfday emails'
  task send_coming_emails: :environment do
    ACP.switch_each! do
      HalfdayParticipation.send_coming_mails
      p "#{Current.acp.name}: Coming halfday emails sent."
    end
  end

  desc 'Charge halfday work that have not been done'
  task charge_missing: :environment do
    ACP.switch_each! do
      Member.all.select { |m| m.remaining_halfday_works.positive? }.each do |member|
        missing_halfdays = member.remaining_halfday_works
        price = missing_halfdays * HalfdayParticipation::PRICE
        membership = member.current_year_membership
        p "#{Current.acp.name}: Member #{member.id}, Facturé #{missing_halfdays} demi-journée(s) de travail à #{price}"
        Membership.transaction do
          membership.decrement(:annual_halfday_works, missing_halfdays)
          membership.increment(:halfday_works_annual_price, price)
          membership.save!
          ActiveAdmin::Comment.create!(
            resource: membership,
            body: "Facturé #{missing_halfdays} demi-journée(s) de travail à #{price}.-",
            namespace: 'root')
        end
      end
    end
  end
end
