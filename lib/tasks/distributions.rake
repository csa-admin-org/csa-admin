namespace :distributions do
  desc 'Send next_delivery emails for distributions'
  task deliver_next_delivery: :environment do
    ACP.enter_each! do
      next_delivery = Delivery.next
      if next_delivery && Date.current == (next_delivery.date - 1.day)
        Distribution.with_emails.each do |distribution|
          Email.deliver_now(:delivery_list, next_delivery, distribution)
        end
        p "#{Current.acp.name}: Distributions next_delivery sent."
      end
    end
  end
end
