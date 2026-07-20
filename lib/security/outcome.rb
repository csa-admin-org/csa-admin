# frozen_string_literal: true

module Security
  Outcome = Data.define(:name, :success, :output, :finished_at) do
    def self.from(name:, success:, output:)
      new(
        name: name,
        success: success,
        output: output.to_s,
        finished_at: Process.clock_gettime(Process::CLOCK_MONOTONIC))
    end

    def success?
      success
    end
  end
end
