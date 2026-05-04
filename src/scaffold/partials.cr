require "./base_resource"

module Creestal
  module Scaffold
    ecr_resource Header, "header.html", "../templates/partials/header.ecr"
    ecr_resource Footer, "footer.html", "../templates/partials/footer.ecr"

    resource_group Partials, Header, Footer
  end
end
