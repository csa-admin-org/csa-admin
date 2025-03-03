# frozen_string_literal: true

# Skip non-interactive terminal
return unless $stdout.tty?

# Helper available in IRB, which helps choosing an Organization to enter.
def enter
  Tenant.disconnect
  tenants = Tenant.numbered

  puts "Select Organization context: (empty for none)"
  tenants.map { |i, tenant|
    puts "–––" if i%100 == 0
    puts "#{i.to_s.rjust(3)}: #{tenant}"
  }

  @selection = gets.strip.presence
  tenant_name = tenants[@selection.to_i] if @selection

  if tenant_name
    Tenant.connect(tenant_name.to_s)
    puts "Connected to \"#{tenant_name}\" context."
  else
    puts "No Organization selected."
  end
end

# Avoid asking again if no tenant was selected.
enter unless defined?(@selection)
