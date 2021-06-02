require 'apartment/elevators/generic'

class ACPElevator < Apartment::Elevators::Generic
  def parse_tenant_name(request)
    host = request.host.split('.')[-2]
    return if host == ENV['ACP_ADMIN_HOST']

    tenant_name = ACP.find_by!(host: host).tenant_name
    Sentry.set_tags(acp: tenant_name)
    tenant_name
  end
end
