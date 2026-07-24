# frozen_string_literal: true

module Style
  Result = Data.define(:mode, :paths, :outcomes) do
    def success? = outcomes.all?(&:success?)
    def failure? = !success?
    def unmatched? = paths.any? && outcomes.empty?

    def failure_message
      names = outcomes.reject(&:success?).map(&:name).join(", ")
      "Style #{mode} failed: #{names}"
    end
  end
end
