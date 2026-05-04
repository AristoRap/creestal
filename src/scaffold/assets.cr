require "./base_resource"

module Creestal
  module Scaffold
    ecr_resource BaseCSS, "css/style.css", "../templates/assets/css/style.ecr"
    ecr_resource ThemeControllerJS, "js/theme_controller.js", "../templates/assets/js/theme_controller.ecr"

    resource_group Assets, BaseCSS, ThemeControllerJS
  end
end
