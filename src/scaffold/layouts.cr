require "./base_resource"

module Creestal
  module Scaffold
    ecr_resource Base, "base.html", "../templates/layouts/base.ecr"

    resource_group Layouts, Base
  end
end
