require 'spec_helper'

describe GitModel::Relations do

  class TestClass
    include GitModel::Relations
  end

  let(:klass) { TestClass }

  describe '.has_many' do

    it 'responds to has_many' do
      klass.should respond_to(:has_many)
    end

    it 'defines the setter and getter' do
      klass.has_many(:toys)
      garage = klass.allocate
      garage.should respond_to(:toys)
      garage.should respond_to(:toys=)
    end

    pending 'proxies via the setters and getters'

  end

  describe '.has_one' do

    it 'responds to has_one' do
      klass.should respond_to(:has_one)
    end

    it 'defines the setter and getter' do
      klass.has_one(:car)
      garage = klass.allocate
      garage.should respond_to(:car)
      garage.should respond_to(:car=)
    end
  end

  describe '.belongs_to' do

    it 'responds to belongs_to' do
      klass.should respond_to(:belongs_to)
    end

    it 'defines the setter and getter' do
      klass.belongs_to(:garage)
      garage = klass.allocate
      garage.should respond_to(:garage)
      garage.should respond_to(:garage=)
    end
  end

end
