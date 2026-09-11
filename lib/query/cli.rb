# frozen_string_literal: true

require "json"
require_relative "client"

module Query
  class CLI
    USAGE = "Usage: bin/query /[/:tenant/...] [--sql SQL] [--page N] [--per N]"

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

    def post?(path)
      path.end_with?("/sql") || path.end_with?("/explain")
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
