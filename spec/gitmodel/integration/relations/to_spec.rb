require 'spec_helper'

describe 'Relations: BelongsTo' do

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
      car.garage = garage
    end

    it 'sets the relation on both sides' do
      garage.car.should == car
      car.garage.should == garage
      car.attributes[:garage_id].should == garage.id
    end

    it 'unsets the relation on both sides' do
      car.garage = nil
      garage.car.should == nil
      car.garage.should == nil
      car.attributes[:garage_id].should == nil
    end

    it 'unsets an existing association when the association is overwritten' do
      other = Garage.create(:id => make_id)
      car.garage = other
      car.garage.should == other
      other.car.should == car
      garage.car.should == nil
      car.attributes[:garage_id].should == other.id
    end

    pending 'saves the association'

    it 'forgets an unsaved assocation on #reload' do
      car.reload
      car.garage.should == nil
      car.attributes[:garage_id].should == nil
      pending { garage.car.should_not == car }
    end

  end

  context 'when an association is set and persisted' do

    before :each do
      garage.car = car
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
      other = Garage.create(:id => make_id)
      car.garage = other
      car.reload
      car.garage.should == garage
      car.attributes[:garage_id].should == garage.id
      garage.car.should == car
    end

  end
end
