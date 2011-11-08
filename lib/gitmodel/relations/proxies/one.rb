module GitModel
  module Relations
    module Proxies
      class One < Proxy

        def get
          @target ||= relation.type.find_all(relation.foreign_key => @owner.id).first
        end

        def set(new_target)
          @target.proxy(relation.inverse).replace(nil) if @target

          replace(new_target)
          new_target.proxy(relation.inverse).replace(@owner) if new_target
        end

        def replace(record)
          @target = record
        end

      end
    end
  end
end
