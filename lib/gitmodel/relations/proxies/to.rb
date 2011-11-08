module GitModel
  module Relations
    module Proxies
      class To < Proxy

        def get
          @target ||= relation.type.find_all(:id => @owner.attributes[relation.foreign_key]).first
        end

        def set(new_target)
          @target.proxy(relation.inverse).replace(nil) if @target

          replace(new_target)
          new_target.proxy(relation.inverse).replace(@owner) if new_target
        end

        def replace(record)
          @target = record
          @owner.attributes[relation.foreign_key] = record && record.id
          # @owner.blobs["#{relation.foreign_key}.ref"] = record && record.id
        end

      end
    end
  end
end
