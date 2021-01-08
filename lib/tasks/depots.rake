namespace :depots do
  desc 'Send next_delivery emails for every depot'
  task deliver_next_delivery: :environment do
    ACP.enter_each! do
      next_delivery = Delivery.next
      if next_delivery && Date.current == (next_delivery.date - 1.day)
        next_delivery.depots.select(&:emails?).each do |depot|
          baskets =
            depot.baskets
              .not_absent
              .not_empty
              .includes(:basket_size, :complements, :member, :baskets_basket_complements)
              .where(delivery_id: next_delivery.id)
              .order('members.name')
              .uniq
          AdminMailer.with(
            depot: depot,
            baskets: baskets,
            delivery: next_delivery
          ).depot_delivery_list_email.deliver_now
        end
        puts "#{Current.acp.name}: Depots next_delivery sent."
      end
    end
  end
end
