namespace :halfdays do
  desc 'Send coming halfday emails'
  task send_coming_emails: :environment do
    HalfdayParticipation.send_coming_mails
    p 'Coming halfday emails sent.'
  end

  desc 'Migrate old HalfdayWork to Halfday'
  task migrate: :environment do
    HalfdayWorkDate.find_each do |hwd|
      hwd.periods.each do |period|
        halfday = Halfday.create!(
          date: hwd.date,
          start_time: hwd.start_time(period),
          end_time: hwd.end_time(period),
          place: hwd.place(period),
          place_url: hwd.place_url(period),
          activity: hwd.activity(period),
          participants_limit: hwd.participants_limit,
          created_at: hwd.created_at)

        halfday_works =
          HalfdayWork.where(date: halfday.date).select { |hw| hw.periods.include?(period) }
        halfday_works.each do |hw|
          halfday.participations.new(
            member_id: hw.member_id,
            validator_id: hw.validator_id,
            state: hw.state,
            validated_at: hw.validated_at,
            rejected_at: hw.rejected_at,
            created_at: hw.created_at,
            participants_count: hw.participants_count,
            carpooling_phone: hw.carpooling_phone
          ).save(validate: false)
        end
      end
    end
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
