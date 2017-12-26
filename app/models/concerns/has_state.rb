module HasState
  extend ActiveSupport::Concern

  class_methods do
    def has_states(*states)
      states.each do |state|
        state_string = state.to_s.freeze
        const_set("#{state}_STATE".upcase, state_string)
        scope state, -> { where(state: state_string) }
        define_method("#{state}?") { self.state == state_string }
      end

      const_set('STATES', states.map(&:to_s).freeze)
    end
  end

  def invalid_transition(action)
    raise "invalid transition '#{action}' on #{self.class.name}(#{id}) in state '#{state}'"
  end
end
