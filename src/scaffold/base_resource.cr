require "ecr"

module Creestal
  module Scaffold
    class BaseResource
      def initialize(@resource : String)
      end
    end

    class ECRResource < BaseResource
      def initialize(@resource : String, @ctx : Core::GeneratorContext)
        super @resource
      end

      def to_h : NamedTuple(file: String, rendered: String)
        {file: @resource, rendered: self.to_s}
      end
    end

    macro ecr_resource(name, file, template)
      class {{name.id}} < ECRResource
        def initialize(@ctx : Core::GeneratorContext)
          super({{file}}, @ctx)
        end

        ECR.def_to_s "#{__DIR__}/{{template.id}}"
      end
    end

    macro resource_group(name, *members)
      class {{name.id}}
        def initialize(@ctx : Core::GeneratorContext)
          {% for m in members %}
            @{{m.id.downcase}} = {{m.id}}.new(@ctx)
          {% end %}
        end

        def resources : Array(NamedTuple(file: String, rendered: String))
          [{% for m in members %}@{{m.id.downcase}}.to_h,{% end %}]
        end
      end
    end
  end
end
