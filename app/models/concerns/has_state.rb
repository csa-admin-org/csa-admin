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

    def state_i18n_names
      const_get('STATES').map { |s| I18n.t("active_admin.status_tag.#{s}") }.sort
    end
  end

  def state_i18n_name
    I18n.t("active_admin.status_tag.#{state}")
  end

  def invalid_transition(action)
    raise "invalid transition '#{action}' on #{self.class.name}(#{id}) in state '#{state}'"
  end
end
