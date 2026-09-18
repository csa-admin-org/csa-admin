# frozen_string_literal: true

require "json"
require_relative "client"

module Query
  class CLI
    USAGE = "Usage: bin/query PATH [flags]   or   bin/query -h"

    def self.start(argv)
      new(argv).run
    rescue Client::Error, Error => e
      warn e.message
      exit 1
    end

    def initialize(argv, client: nil, out: $stdout)
      @argv = argv.dup
      @client = client
      @out = out
    end

    def run
      if help?
        @out.puts help_text
        return
      end

      path = @argv.shift
      raise Error, USAGE unless path&.start_with?("/")

      body = client_params
      if blob?(path)
        @out.binmode if @out.respond_to?(:binmode)
        @out.write(client.download(path))
      else
        result = post?(path) ? client.post(path, body) : client.get(path, body)
        @out.puts JSON.pretty_generate(result)
      end
    end

    private

    class Error < StandardError; end

    def client
      @client ||= Client.new
    end

    def help?
      @argv.empty? || %w[-h --help].include?(@argv.first)
    end

    def api_url
      ENV.fetch("CSA_ADMIN_API_URL", Client::DEFAULT_URL)
    end

    def help_text
      <<~HELP
        Query API
          #{api_url}
          Auth: CSA_ADMIN_API_TOKEN (#{token_state})
          Override host: CSA_ADMIN_API_URL

        #{USAGE}

        Fleet (no /:tenant in the path). Skip demo/custom.
        Optional --tenant SLUG[,SLUG] intersects the token allowlist (query
        string on GET, JSON body on POST). Not a path param.

          bin/query /
          bin/query /organizations --attributes absences_included_mode,features
          bin/query /organizations --absences_included_mode provisional_absence
          bin/query /bank_connections --provider ebics --state ready
          bin/query /tickets/search --q absences --per 20
          bin/query /tickets/search --q EBICS --tenant lamule,ortie

        One tenant (path /:tenant). Webhook already has the slug.
        Never GET ?sql= / GET ?q=.

          bin/query /lamule/schema
          bin/query /lamule/schema/invoices
          bin/query /lamule/models
          bin/query /lamule/sql --sql 'SELECT id, state FROM invoices WHERE id = 310'
          bin/query /lamule/explain --sql 'SELECT * FROM baskets WHERE membership_id = 12'
          bin/query /lamule/blobs/42 > invoice.pdf

        Flags: --sql --q --tenant --attributes --provider --state --active
               --page --per  (and other GET query / POST JSON keys)
      HELP
    end

    def token_state
      ENV["CSA_ADMIN_API_TOKEN"].to_s.empty? ? "missing" : "set"
    end

    def post?(path)
      path.end_with?("/sql") || path.end_with?("/explain") || path == "/tickets/search"
    end

    def blob?(path)
      path.match?(%r{/blobs/\d+\z})
    end

    def client_params
      params = {}
      until @argv.empty?
        flag = @argv.shift
        raise Error, USAGE unless flag.start_with?("--")

        params[flag.delete_prefix("--").tr("-", "_")] = @argv.shift
      end
      params.compact
    end
  end
end
