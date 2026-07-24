# frozen_string_literal: true

module Security
  Result = Data.define(:outcomes) do
    def success? = outcomes.all?(&:success?)
    def failure? = !success?

    def failure_message
      names = outcomes.reject(&:success?).map(&:name).join(", ")
      "Security check failed: #{names}"
    end
  end
end
