namespace :postmark do
  desc 'Sync Postmark Suppressions'
  task sync_suppressions: :environment do
    ACP.enter_each! do
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
      puts "#{Current.acp.name}: Email Suppressions list synced."
    end
  end

  desc 'Create/update message streams'
  task message_streams_setup: :environment do
    ACP.enter_each! do
      if api_token = Current.acp.credentials(:postmark, :api_token)
        client = Postmark::ApiClient.new(api_token)

        outbound = client.get_message_stream('outbound')
        unless outbound[:name] == 'Transactional Stream'
          client.update_message_stream('outbound', name: 'Transactional Stream')
        end

        inbound = client.get_message_stream('inbound')
        unless inbound[:name] == 'Inbound Stream'
          client.update_message_stream('inbound', name: 'Inbound Stream')
        end

        if client.message_streams.none? { |s| s[:id] == 'broadcast' }
          client.create_message_stream(
            id: 'broadcast',
            name: 'Broadcasts Stream',
            message_stream_type: 'Broadcasts')
        end
      end
    end
  end
end
