class Car
  include GitModel::Persistable
  belongs_to :garage
  attribute :doors
end
