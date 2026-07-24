# frozen_string_literal: true

module Style
  Outcome = Data.define(:name, :success, :output) do
    def self.from(name:, success:, output:)
      new(name:, success:, output: output.to_s)
    end

    def success?
      success
    end
  end
end
