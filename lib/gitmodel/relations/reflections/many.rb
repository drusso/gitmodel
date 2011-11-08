module GitModel
  module Relations
    module Reflections
      class Many < Reflection

        def proxy
          GitModel::Relations::Proxies::Many
        end

        def default_foreign_key
        end

      end
    end
  end
end
