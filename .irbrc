# frozen_string_literal: true

require "readline"

def enter
  Tenant.disconnect

  Readline.completion_proc = proc { |s| Tenant.all_with_aliases.grep(/^#{Regexp.escape(s)}/) }
  tenant = Readline.readline("Enter tenant name (empty for none): ", true).strip.presence
  tenant = Tenant.find_with_aliases(tenant)

  if tenant && Tenant.exists?(tenant)
    Tenant.connect(tenant)
    tenant
  elsif tenant
    puts "Invalid tenant name: \"#{tenant}\"."
  else
    puts "No Organization selected."
  end
end

env = Rails::Console::IRBConsole.new(Rails.application).colorized_env
prompt_prefix = "%N(#{env}, %TENANT)"
IRB.conf[:PROMPT][:TENANT_PROMPT] = {
  PROMPT_I: "#{prompt_prefix}> ",
  PROMPT_S: "#{prompt_prefix}%l ",
  PROMPT_C: "#{prompt_prefix}* ",
  RETURN: "=> %s\n"
}
IRB.conf[:PROMPT_MODE] = :TENANT_PROMPT

# Monkey-patch IRB prompt formating to have live tenant name injected
module IrbTenantPrompt
  def format_prompt(format, ltype, indent, line_no)
    color = Rails.env.local? ? :BLUE : :RED
    tenant = IRB::Color.colorize(Tenant.current || "NONE", [ color ])
    format = format.dup.gsub(/%TENANT/, tenant)
    super
  end
end

module IRB
  class Irb
    prepend IrbTenantPrompt
  end
end

enter
