# frozen_string_literal: true

# Skip non-interactive terminal
return unless $stdout.tty?

# Helper available in IRB, which helps choosing an Organization to enter.
def enter
  Tenant.disconnect
  tenants = Tenant.all

  puts "Select Organization context: (empty for none)"
  puts tenants.map.with_index { |tenant, i| "#{(i + 1).to_s.rjust(2)}: #{tenant}" }.join("\n")

  @selection = gets.strip.presence
  tenant_name = tenants[@selection.to_i - 1] if @selection

  if tenant_name
    Tenant.connect(tenant_name.to_s)
    puts "Connected to \"#{tenant_name}\" context."
  else
    puts "No Organization selected."
  end
end

# Avoid asking again if no tenant was selected.
enter unless defined?(@selection)
