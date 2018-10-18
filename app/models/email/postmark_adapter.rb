require 'email'

module Email
  class PostmarkAdapter
    def initialize(api_token)
      @client = Postmark::ApiClient.new(api_token)
    end

    def deliver(from:, to:, template:, template_data:, attachments: [])
      request(:deliver_with_template,
        from: from,
        to: ENV['POSTMARK_TO'] || to,
        template_alias: template,
        template_model: template_data,
        attachments: prepare_attachments(attachments))
    end

    private

    def prepare_attachments(attachments = [])
      attachments.each do |attachment|
        attachment[:content] = [attachment[:content]].pack('m')
      end
    end

    def request(action, **args)
      @client.send(action, **args)
    rescue Postmark::Error => ex
      ExceptionNotifier.notify(ex, args.except(:attachments).merge(
        attachments: args[:attachments].map { |a| a.except(:content) }))
    end
  end
end
