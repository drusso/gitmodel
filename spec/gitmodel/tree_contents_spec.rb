require 'spec_helper'

describe GitModel::TreeContents do

  let(:tree) do
    {
      :foo => '1',
      :bar => {
        :foo => '2',
        :bar => '3',
        :baz => {
          :foo => '4',
          :bar => '5'
        } 
      }
    }
  end

  let(:falsey_path) do
    { :bar => { :baz => { :bar => false } } }
  end

  let(:record) do
    record = TestEntity.new(:id => 'foo')
    record.tree = tree
    record
  end

  describe '#tree' do

    it 'should return a HashWithIndifferentAccess' do
      TestEntity.new.contents.should be_a HashWithIndifferentAccess
    end

  end

  describe '#tree=' do

    context 'when given a Hash' do

      it 'sets a HashWithIndifferentAccess' do
        record.tree.should be_a HashWithIndifferentAccess
        record.tree['foo'].should == '1'
        record.tree['bar'].should be_a HashWithIndifferentAccess
        record.tree['bar']['foo'].should == '2'
        record.tree['bar']['bar'].should == '3'
        record.tree['bar']['baz'].should be_a HashWithIndifferentAccess
        record.tree['bar']['baz']['foo'].should == '4'
        record.tree['bar']['baz']['bar'].should == '5'
      end

    end

    context 'when given an Array of Grit::Trees and Grit::Blobs' do

      let(:array_of_grit_objects) do
        r = TestEntity.new(:id => 'foo')
        r.tree = tree
        r.save
        array_of_grit_objects = (Grit::Repo.new(GitModel.db_root).tree/r.path).contents
      end

      it 'sets a HashWithIndifferentAccess' do
        record.tree = array_of_grit_objects
        record.tree.should be_a HashWithIndifferentAccess
        record.tree['foo'].should == '1'
        record.tree['bar'].should be_a HashWithIndifferentAccess
        record.tree['bar']['foo'].should == '2'
        record.tree['bar']['bar'].should == '3'
        record.tree['bar']['baz'].should be_a HashWithIndifferentAccess
        record.tree['bar']['baz']['foo'].should == '4'
        record.tree['bar']['baz']['bar'].should == '5'
      end

    end

  end

  describe '#paths' do

    it 'yields, for each blob, with a path relative to the supplied path' do
      record = TestEntity.new(:id => 'foo')
      record.tree = tree.deep_merge(falsey_path)

      expected_paths = {
        "#{record.path}/foo" => '1',
        "#{record.path}/bar/foo" => '2',
        "#{record.path}/bar/bar" => '3',
        "#{record.path}/bar/baz/foo" => '4',
        "#{record.path}/bar/baz/bar" => false
      }

      record.paths(record.path) do |path, data|
        expected_data = expected_paths.delete(path)
        expected_data.should_not be_nil
        expected_data.should == data
      end

      expected_paths.length.should == 0
    end

  end

end
