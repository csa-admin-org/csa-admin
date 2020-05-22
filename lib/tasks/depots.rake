namespace :depots do
  desc 'Send next_delivery emails for every depot'
  task deliver_next_delivery: :environment do
    ACP.enter_each! do
      next_delivery = Delivery.next
      if next_delivery && Date.current == (next_delivery.date - 1.day)
        next_delivery.depots.with_emails.each do |depot|
          Email.deliver_now(:admin_delivery_list, next_delivery, depot)
        end
        puts "#{Current.acp.name}: Depots next_delivery sent."
      end
    end
  end
end
