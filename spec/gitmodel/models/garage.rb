class Garage
  include GitModel::Persistable
  has_one :car
  attribute :size
end
