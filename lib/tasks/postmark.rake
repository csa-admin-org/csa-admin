namespace :postmark do
  desc 'Create/update message streams'
  task message_streams_setup: :environment do
    ACP.switch_each do |acp|
      if api_token = acp.credentials(:postmark, :api_token)
        client = Postmark::ApiClient.new(api_token)

        outbound = client.get_message_stream('outbound')
        unless outbound[:name] == 'Transactional Stream'
          client.update_message_stream('outbound', name: 'Transactional Stream')
        end

        inbound = client.get_message_stream('inbound')
        unless inbound[:name] == 'Inbound Stream'
          client.update_message_stream('inbound', name: 'Inbound Stream')
        end

        brodcast = client.get_message_stream('broadcast')
        unless brodcast[:name] == 'Broadcasts Stream'
          client.update_message_stream('broadcast', name: 'Broadcasts Stream')
        end
      end
    end
  end
end
