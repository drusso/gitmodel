module GitModel
  module Relations
    module Proxies
      class Many < Proxy

        def get
          self
        end

        def set(target)
          @target.unset
          @target = target
          @source.attributes[relation.foreign_key] = target.id
        end

        def unset
          @target = nil
          @source.attributes[relation.foreign_key] = nil
        end

      end
    end
  end
end
