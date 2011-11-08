module GitModel
  module Relations
    module Reflections
      class One < Reflection

        def proxy
          GitModel::Relations::Proxies::One
        end

        def default_foreign_key
          :"#{inverse}_id"
        end

      end
    end
  end
end
