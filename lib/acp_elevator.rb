require 'apartment/elevators/generic'

class ACPElevator < Apartment::Elevators::Generic
  def parse_tenant_name(request)
    host = request.host.split('.')[-2]
    ACP.find_by!(host: host).tenant_name
  end
end
