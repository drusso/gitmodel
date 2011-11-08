require 'spec_helper'

describe 'Relations: HasOne' do

  before :each do
    # For GitModel to create indexes for Car and Garage
    Car.create!(:id => make_id, :garage => Garage.create(:id => make_id) )
    GitModel.index!('master')
  end

  let(:car)    { Car.create(:id => make_id) }
  let(:garage) { Garage.create(:id => make_id) }

  context 'when an association is not set' do

    it 'returns nil' do  
      garage.car.should == nil
      car.garage.should == nil
      car.attributes[:garage_id].should == nil
    end

  end

  context 'when an association is set but not persisted' do

    before :each do
      garage.car = car
    end

    it 'sets the relation on both sides' do
      garage.car.should == car
      car.garage.should == garage
      car.attributes[:garage_id].should == garage.id
    end

    it 'unsets the relation on both sides' do
      garage.car = nil
      garage.car.should == nil
      car.garage.should == nil
      car.attributes[:garage_id].should == nil
    end

    it 'unsets an existing association when the association is overwritten' do
      other = Car.create(:id => make_id)
      garage.car = other
      garage.car.should == other
      car.garage.should == nil
      other.garage.should == garage
      other.attributes[:garage_id].should == garage.id
      car.attributes[:garage_id].should == nil
    end

    pending 'saves the association'

    it 'forgets an unsaved assocation on #reload' do
      garage.reload
      garage.car.should == nil
      pending { car.attributes[:garage_id].should_not == garage.id }
      pending { car.garage.should_not == garage }
    end

  end

  context 'when an association is set and persisted' do

    before :each do
      garage.car = car

      # Persist the association from the BelongsTo side since saving on 
      # the HasOne side does not save the associated BelongsTo relation 
      # (which stores the foreign key)
      car.save
      GitModel.index! 'master'
    end

    it 'loads the relation' do
      garage.reload
      garage.car.should == car
      car.reload
      car.garage.should == garage
      car.attributes[:garage_id].should == garage.id
    end

    it 'forgets an unsaved assocation on #reload' do    
      other = Car.create(:id => make_id)
      garage.car = other
      garage.reload
      garage.car.should == car
      pending { car.attributes[:garage_id].should == garage.id }
      pending { car.garage.should == garage }
    end

  end
end
