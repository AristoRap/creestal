require "./base_resource"

module Creestal
  module Scaffold
    ecr_resource Procfile, "Procfile", "../templates/scripts/Procfile.ecr"

    resource_group Scripts, Procfile
  end
end
