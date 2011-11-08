module GitModel
  module Relations
    module Reflections
      class To < Reflection

        def proxy
          GitModel::Relations::Proxies::To
        end

        def default_foreign_key
          :"#{name}_id"
        end

      end
    end
  end
end
