require 'spec_helper'
require 'active_model/lint'

describe GitModel::Persistable do

  context 'lint' do
    let(:model) { TestEntity.new }

    include ActiveModel::Lint::Tests

    it 'must implement the #to_key interface' do
      test_to_key
    end

    it 'must implement the #to_param interface' do
      test_to_param
    end

    it 'must implement the #valid? interface' do
      test_valid?
    end

    it 'must implement the #persisted? interface' do
      test_persisted?
    end

    it 'must implement the #model_naming interface' do
      test_model_naming
    end

    it 'must implement the #errors interface' do
      test_errors_aref
      test_errors_full_messages
    end

  end

  describe '#save' do

    it 'raises an exception if the id is not set' do
      o = TestEntity.new
      lambda {o.save}.should raise_error(GitModel::NullId)
    end

    it 'stores an instance in a Git repository in a subdir of db_root named with the id' do
      id = 'foo'
      TestEntity.create!(:id => id)
      
      repo = Grit::Repo.new(GitModel.db_root)
      (repo.commits.first.tree / File.join(TestEntity.db_subdir, id, 'attributes.json')).data.should_not be_nil
    end

    it 'stores attributes in the attributes.json file' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      TestEntity.create!(:id => id, :attributes => attrs)

      repo = Grit::Repo.new(GitModel.db_root)
      attrs = (repo.commits.first.tree / File.join(TestEntity.db_subdir, id, 'attributes.json')).data
      r = Yajl::Parser.parse(attrs)
      r.size.should == 2
      r['one'].should == 1
      r['two'].should == 2
    end

    context 'when storing trees and blobs' do

      let(:tree) do
        {
          :christmas => {
            :ornament => 'a',
            :light => 'b',
            :branch => {
              :short => 'c',
              :long => 'd'
            }
          },
          :break => 'blob content'
        }
      end

      it 'stores blobs as files and they are appropriately nested within directories' do
        record = TestEntity.create(:id => 'foo', :tree => tree)

        paths_that_should_exist = %w[
          christmas/
          christmas/ornament
          christmas/light/
          christmas/branch/short
          christmas/branch/long
          break
        ]

        root = Grit::Repo.new(GitModel.db_root).tree / record.path
        paths_that_should_exist.each { |path| (root/path).should_not == nil }
      end

      it 'deletes blobs that are explicitly excluded from the record\'s tree' do
        record = TestEntity.create(:id => 'foobar', :tree => tree)
        record.tree = { :christmas => { :branch => { :short => false } } }
        record.save

        paths_that_should_exist = %w[
          christmas/
          christmas/ornament
          christmas/light/
          christmas/branch/long
          break
        ]

        paths_that_should_not_exist = %w[
          christmas/branch/short
        ]

        root = Grit::Repo.new(GitModel.db_root).tree/record.path
        paths_that_should_exist.each { |p| (root/p).should_not == nil }
        paths_that_should_not_exist.each { |p| (root/p).should == nil }
      end

      it 'ignores an attributes.json blob when saving the tree' do
        record = TestEntity.new(:id => 'foobar')
        record.attributes = { :foo => 100 }
        record.tree = tree.merge({ 'attributes.json' => 'xyz' })
        record.save

        # Before reload
        record.attributes['foo'].should == 100
        record.tree['attributes.json'].should == 'xyz'

        # Check the contents of attribute.json
        attributes_file_content = (Grit::Repo.new(GitModel.db_root).tree/record.path/'attributes.json').data
        attributes_file_content.should_not == 'xyz'

        # After reload
        record.reload
        record.attributes['foo'].should == 100
        record.tree['attributes.json'].should == nil
      end

    end

    it 'returns false if the validations failed'

    it 'returns the SHA of the commit if the save was successful'

    it 'updates the index' do
      # TODO
    end
  end

  describe '#save!' do
    
    it "calls save and returns the non-false and non-nil result"

    it "calls save and raises an exception if the result is nil"
    
    it "calls save and raises an exception if the result is false"

  end

  describe '#load' do

    let(:path) do
      File.join(TestEntity.db_subdir, 'foo')
    end

    let(:record) do
      record = TestEntity.new
      record.send(:load, path, 'master')
      record
    end

    context 'when the record does not exist' do

      it 'raises an exception if the document is not found' do
        lambda { TestEntity.new.send(:load, path, 'master') }.should raise_error
      end

    end

    context 'when the record exists' do

      before do
        attrs = { :one => 1, :two => 2 }
        tree = {
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

        TestEntity.create(:id => 'foo', :attributes => attrs, :tree => tree)
      end

      it 'returns the loaded instance' do
        record = TestEntity.new
        record.send(:load, path, 'master').should == record
      end

      it 'loads attributes' do
        record.attributes['one'].should == 1
        record.attributes['two'].should == 2
      end

      it 'loads trees and blobs' do
        record.tree['foo'].should == '1'
        record.tree['bar']['foo'].should == '2'
        record.tree['bar']['bar'].should == '3'
        record.tree['bar']['baz'].should be_a Hash
        record.tree['bar']['baz']['foo'].should == '4'
        record.tree['bar']['baz']['bar'].should == '5'
      end

      it 'does not load attribute.json into the tree' do
        record.tree['attributes.json'].should == nil
      end

      context 'when the record is already loaded' do

        it 'reloads persisted attributes' do
          record.attributes['one'] = 100
          record.attributes['unsaved'] = 'foo'
          record.send(:load, path, 'master')
          record.attributes['one'].should == 1
          record.attributes['two'].should == 2
          record.attributes['unsaved'].should == nil
        end

        it 'reloads the tree' do
          record.tree['foo'] = 100
          record.tree['unsaved'] = 'foo'
          record.send(:load, path, 'master')
          record.tree['foo'].should == '1'
          record.tree['unsaved'] == nil
        end

      end

    end

  end

  describe '#new' do

    it 'creates a new unsaved instance' do
      TestEntity.new.new_record?.should be_true
    end

    it 'takes an optional hash to set id' do
      TestEntity.new(:id => 'foo').id.should == 'foo'
    end

    it 'takes an optional hash to set attributes' do
      record = TestEntity.new(:attributes => { :one => 1 })
      record.attributes['one'].should == 1
    end

    it 'takes an optional hash to set the tree' do
      record = TestEntity.new(:tree => { :foo => 'blob', :bar => {} })
      record.tree['foo'].should == 'blob'
      record.tree['bar'].should == {}
    end

    it 'takes values for each defined attribute' do
      foo = TestEntity.dup
      foo.attribute(:bar)
      record = foo.new(:bar => 'baz')
      record.bar.should == 'baz'
    end

    it 'takes values for each defined blob' do
      foo = TestEntity.dup
      foo.blob(:bar)
      record = foo.new(:bar => 'a')
      record.tree['bar'].should == 'a'
    end

    it 'takes values for each defined tree' do
      foo = TestEntity.dup
      foo.tree(:bar)
      record = foo.new(:bar => { :baz => 'blob' })
      record.tree['bar']['baz'].should == 'blob'
    end

  end

  describe '#reload' do

    let(:record) do
      TestEntity.create(:id => 'foo')
    end

    it 'calls load on the instance' do
      record.should_receive(:load).with(record.path, record.branch)
      record.reload
    end

    it 'returns the reloaded instance' do
      record.reload.should == record
    end

    it 'raises an exception if the document is not found' do
      lambda { TestEntity.new.reload }.should raise_error
      lambda { TestEntity.new(:id => 'foo').reload }.should raise_error
    end

  end

  describe'#reload' do

    it 'reloads persisted attributes' do
      o = TestEntity.new(:id => "_id_")
      o.attributes['A'] = 'A'
      o.save
      o.attributes['B'] = 'B'

      o.attributes['A'].should == 'A'
      o.attributes['B'].should == 'B'
      o.reload
      o.attributes['A'].should == 'A'
      o.attributes['B'].should == nil
    end

    pending 'reloads the instance from the branch that the instance was initially loaded from or last saved to'

    it 'removes relational proxies' do
      o = TestEntity.new(:id => "foo")
      o.save
      o.should_receive(:reset_proxies)
      o.reload
    end

    it 'raises an exception if the document is not found' do
      lambda { TestEntity.new.reload }.should raise_error
      lambda { TestEntity.new(:id => "foo").reload }.should raise_error
    end

    pending 'calls initializization callbacks'

  end

  describe '.create' do
    
    it 'creates a new instance with the given parameters and calls #save on it' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      blobs = {'blob1.txt' => 'This is blob 1'}

      new_mock = mock("new_mock")
      TestEntity.should_receive(:new).with(:id => id, :attributes => attrs, :tree => blobs).and_return(new_mock)
      new_mock.should_receive(:save)

      TestEntity.create(:id => id, :attributes => attrs, :tree => blobs)
    end

    it 'returns an instance of the record created' do
      o = TestEntity.create(:id => 'lemur')
      o.should be_a(TestEntity)
      o.id.should == 'lemur'
    end

    describe 'with a single array as a parameter' do

      it 'creates a new instance with each element of the array as parameters and calls #save on it' do
        args = [
          {:id => 'foo', :attributes => {:one => 1}, :blobs => {'blob1.txt' => 'This is blob 1'}},
          {:id => 'bar', :attributes => {:two => 2}, :blobs => {'blob2.txt' => 'This is blob 2'}}
        ]

        new_mock1 = mock("new_mock1")
        new_mock2 = mock("new_mock2")
        TestEntity.should_receive(:new).with(args[0]).once.and_return(new_mock1)
        TestEntity.should_receive(:new).with(args[1]).once.and_return(new_mock2)
        new_mock1.should_receive(:save)
        new_mock2.should_receive(:save)

        TestEntity.create(args) 
      end

    end

  end

  describe '.create!' do

    it 'creates a new instance with the given parameters and calls #save! on it' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      blobs = {'blob1.txt' => 'This is blob 1'}

      new_mock = mock("new_mock")
      TestEntity.should_receive(:new).with(:id => id, :attributes => attrs, :tree => blobs).and_return(new_mock)
      new_mock.should_receive(:save!)

      TestEntity.create!(:id => id, :attributes => attrs, :tree => blobs)
    end

    it 'returns an instance of the record created' do
      o = TestEntity.create!(:id => 'lemur')
      o.should be_a(TestEntity)
      o.id.should == 'lemur'
    end

    describe 'with a single array as a parameter' do
      it 'creates a new instance with each element of the array as parameters and calls #save! on it' do
        args = [
          {:id => 'foo', :attributes => {:one => 1}, :blobs => {'blob1.txt' => 'This is blob 1'}},
          {:id => 'bar', :attributes => {:two => 2}, :blobs => {'blob2.txt' => 'This is blob 2'}}
        ]

        new_mock1 = mock("new_mock1")
        new_mock2 = mock("new_mock2")
        TestEntity.should_receive(:new).with(args[0]).once.and_return(new_mock1)
        TestEntity.should_receive(:new).with(args[1]).once.and_return(new_mock2)
        new_mock1.should_receive(:save!)
        new_mock2.should_receive(:save!)

        TestEntity.create!(args) 
      end
    end

  end

  describe '.delete' do

    it 'deletes the object with the given id from the database' do
      TestEntity.create!(:id => 'monkey')
      TestEntity.delete('monkey')

      TestEntity.exists?('monkey').should be_false
    end

    it 'also deletes blobs associated with the given object' do
      id = 'Lemuridae'
      TestEntity.create!(:id => id, :tree => {:crowned => "Eulemur coronatus", :brown => "Eulemur fulvus"})
      b = GitModel.default_branch
      (GitModel.current_tree(b) / File.join(TestEntity.db_subdir, id, 'crowned')).data.should_not be_nil
      (GitModel.current_tree(b) / File.join(TestEntity.db_subdir, id, 'brown')).data.should_not be_nil
      TestEntity.delete(id)

      (GitModel.current_tree(b) / File.join(TestEntity.db_subdir, id, 'attributes.json')).should be_nil
      (GitModel.current_tree(b) / File.join(TestEntity.db_subdir, id, 'attributes.json')).should be_nil

      (GitModel.current_tree(b) / File.join(TestEntity.db_subdir, id, 'crowned')).should be_nil
      (GitModel.current_tree(b) / File.join(TestEntity.db_subdir, id, 'brown')).should be_nil
    end


  end

  describe '.delete_all' do

    it 'deletes all objects of the same type from the database' do
      TestEntity.create!(:id => 'monkey')
      TestEntity.create!(:id => 'ape')

      TestEntity.delete_all
      TestEntity.index!(GitModel.default_branch)
      TestEntity.find_all.should be_empty
    end

  end

  describe '#delete' do

    it 'deletes the object from the database' do
      o = TestEntity.create!(:id => 'monkey')
      o.delete

      TestEntity.exists?('monkey').should be_false
    end

    it 'freezes the object' do
      o = TestEntity.create!(:id => 'monkey')
      o.delete

      o.frozen?.should be_true
    end

  end

  describe '.find' do

    #it 'can load an object from an empty subdir of db_root' do
    #  id = "foo"
    #  dir = File.join(GitModel.db_root, TestEntity.db_subdir, id)
    #  FileUtils.mkdir_p dir

    #  o = TestEntity.find(id)
    #  o.id.should == id
    #  o.attributes.should be_empty
    #  o.blobs.should be_empty
    #end
    
    describe 'with no commits in the repo' do

      it 'raises GitModel::RecordNotFound if a record with the given id doesn\'t exist' do
        lambda{TestEntity.find('missing')}.should raise_error(GitModel::RecordNotFound)
      end

    end
    
    it 'raises GitModel::RecordNotFound if a record with the given id doesn\'t exist' do
      TestEntity.create!(:id => 'something')
      lambda{TestEntity.find('missing')}.should raise_error(GitModel::RecordNotFound)
    end

    it 'can load an object with attributes and no blobs' do
      id = "foo"
      attrs = {:one => 1, :two => 2}
      TestEntity.create!(:id => id, :attributes => attrs)

      o = TestEntity.find(id)
      o.id.should == id
      o.attributes.size.should == 2
      o.attributes['one'].should == 1
      o.attributes['two'].should == 2
      o.tree.should be_empty
    end

    it 'can load an object with blobs and no attributes' do
      id = 'foo'
      blobs = {'blob1.txt' => 'This is blob 1', 'blob2' => 'This is blob 2'}
      TestEntity.create!(:id => id, :tree => blobs)

      o = TestEntity.find(id)
      o.id.should == id
      o.attributes.should be_empty
      o.tree.size.should == 2
      o.tree["blob1.txt"].should == 'This is blob 1'
      o.tree["blob2"].should == 'This is blob 2'
    end

    it 'can load an object with both attributes and blobs' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      blobs = {'blob1.txt' => 'This is blob 1', 'blob2' => 'This is blob 2'}
      TestEntity.create!(:id => id, :attributes => attrs, :tree => blobs)

      o = TestEntity.find(id)
      o.id.should == id
      o.attributes.size.should == 2
      o.attributes['one'].should == 1
      o.attributes['two'].should == 2
      o.tree.size.should == 2
      o.tree["blob1.txt"].should == 'This is blob 1'
      o.tree["blob2"].should == 'This is blob 2'
    end

  end

  describe '.find_all' do
    describe 'with no parameters' do
      it 'returns an array of all objects' do
        TestEntity.create!(:id => 'one')
        TestEntity.create!(:id => 'two')
        TestEntity.create!(:id => 'three')

        r = TestEntity.find_all
        r.size.should == 3
      end

      it 'returns an empty array if there are no objects of the current type' do
        r = TestEntity.find_all
        r.should == []
      end
    end

    describe 'with conditions but no index' do
      it 'raises an exception' do
        TestEntity.create!(:id => 'one')
        lambda {TestEntity.find_all(:a => "b")}.should raise_error(GitModel::IndexRequired)
      end
    end

    describe 'with one condition' do
      describe 'with a literal value' do
        it 'returns an array of all objects that match' do
          TestEntity.create!(:id => 'one', :attributes => {:a => 1, :b => 1})
          TestEntity.create!(:id => 'two', :attributes => {:a => 2, :b => 2})
          TestEntity.create!(:id => 'three', :attributes => {:a => 1, :b => 3})
          TestEntity.index!(GitModel.default_branch)

          r = TestEntity.find_all(:a => 1)
          r.size.should == 2
          r.first.id.should == 'one'
          r.second.id.should == 'three'
        end
      end

      describe 'with a lambda as the value' do
        it 'returns an array of all objects that match' do
          TestEntity.create!(:id => 'one', :attributes => {:a => 1, :b => 1})
          TestEntity.create!(:id => 'two', :attributes => {:a => 2, :b => 2})
          TestEntity.create!(:id => 'three', :attributes => {:a => 1, :b => 3})
          TestEntity.index!(GitModel.default_branch)

          r = TestEntity.find_all(:b => lambda{|b| b > 1}, :order => :asc)
          r.size.should == 2
          r.first.id.should == 'three'
          r.second.id.should == 'two'
        end
      end
    end

    describe 'with multiple conditions' do
      describe 'with a literal value' do
        it 'returns an array of all objects that match both (i.e. AND)' do
          TestEntity.create!(:id => 'one', :attributes => {:a => 1, :b => 2})
          TestEntity.create!(:id => 'two', :attributes => {:a => 1, :b => 2})
          TestEntity.create!(:id => 'three', :attributes => {:a => 1, :b => 1})
          TestEntity.index!(GitModel.default_branch)

          r = TestEntity.find_all(:a => 1, :b => 2, :order => :asc)
          r.size.should == 2
          r.first.id.should == 'one'
          r.second.id.should == 'two'
        end
      end

      describe 'with a lambda as the value' do
        it 'returns an array of all objects that match both (i.e. AND)'  do
          TestEntity.create!(:id => 'one', :attributes => {:a => 1, :b => 3})
          TestEntity.create!(:id => 'two', :attributes => {:a => 2, :b => 2})
          TestEntity.create!(:id => 'three', :attributes => {:a => 1, :b => 1})
          TestEntity.create!(:id => 'four', :attributes => {:a => 3, :b => 3})
          TestEntity.index!(GitModel.default_branch)

          r = TestEntity.find_all(:a => lambda{|a| a > 1}, :b => lambda{|b| b > 2}, :order => :asc)
          r.size.should == 1
          r.first.id.should == 'four'
        end

      end
    end

    describe 'with the id attribute in the conditions' do
      describe 'with a literal value' do
        it 'returns an array that includes the object with that id' do
          TestEntity.create!(:id => 'one')
          TestEntity.create!(:id => 'two')
          TestEntity.create!(:id => 'three')

          r = TestEntity.find_all(:id => 'one')
          r.size.should == 1
          r.first.id.should == 'one'
        end
      end

      describe 'with a lambda as the value' do
        it 'returns an array that includes the object with that id' do
          TestEntity.create!(:id => 'one')
          TestEntity.create!(:id => 'two')
          TestEntity.create!(:id => 'three')

          r = TestEntity.find_all(:id => lambda{|id| id =~ /o/})
          r.size.should == 2
          r.first.id.should == 'one'
          r.second.id.should == 'two'
        end

      end
    end

    it 'can return results in ascending order' do
      TestEntity.create!(:id => 'one', :attributes => {:a => 1, :b => 1})
      TestEntity.create!(:id => 'two', :attributes => {:a => 2, :b => 2})
      TestEntity.create!(:id => 'three', :attributes => {:a => 1, :b => 3})
      TestEntity.index!(GitModel.default_branch)

      r = TestEntity.find_all(:a => 1, :order => :asc)
      r.size.should == 2
      r.first.id.should == 'one'
      r.second.id.should == 'three'
    end

    it 'can return results in descending order' do
      TestEntity.create!(:id => 'one', :attributes => {:a => 1, :b => 1})
      TestEntity.create!(:id => 'two', :attributes => {:a => 2, :b => 2})
      TestEntity.create!(:id => 'three', :attributes => {:a => 1, :b => 3})
      TestEntity.index!(GitModel.default_branch)

      r = TestEntity.find_all(:a => 1, :order => :desc)
      r.size.should == 2
      r.first.id.should == 'three'
      r.second.id.should == 'one'
    end

    it 'can limit the number of results returned with ascending order' do
      TestEntity.create!(:id => 'one', :attributes => {:a => 1, :b => 1})
      TestEntity.create!(:id => 'two', :attributes => {:a => 1, :b => 2})
      TestEntity.create!(:id => 'three', :attributes => {:a => 1, :b => 3})
      TestEntity.index!(GitModel.default_branch)

      r = TestEntity.find_all(:a => 1, :order => :asc, :limit => 2)
      r.size.should == 2
      r.first.id.should == 'one'
      r.second.id.should == 'three'
    end

    it 'can limit the number of results returned with descending order' do
      TestEntity.create!(:id => 'one', :attributes => {:a => 1, :b => 1})
      TestEntity.create!(:id => 'two', :attributes => {:a => 1, :b => 2})
      TestEntity.create!(:id => 'three', :attributes => {:a => 1, :b => 3})
      TestEntity.index!(GitModel.default_branch)

      r = TestEntity.find_all(:a => 1, :order => :desc, :limit => 2)
      r.size.should == 2
      r.first.id.should == 'two'
      r.second.id.should == 'three'
    end

  end

  describe '.exists?' do

    it 'returns true if the record exists' do
      TestEntity.create!(:id => 'one')
      TestEntity.exists?('one').should be_true
    end

    it "returns false if the record doesn't exist" do
      TestEntity.exists?('missing').should be_false
    end

  end

  describe ".index!" do
    it "generates and saves the index" do
      TestEntity.index.should_receive(:generate!)
      TestEntity.index.should_receive(:save)
      TestEntity.index!(GitModel.default_branch)
    end
  end

  describe '.all_values_for_attr' do
    it 'returns a list of all values that exist for a given attribute' do
      o = TestEntity.create!(:id => 'first', :attributes => {"a" => 1, "b" => 2})
      o = TestEntity.create!(:id => 'second', :attributes => {"a" => 3, "b" => 4})
      TestEntity.index!(GitModel.default_branch)
      TestEntity.all_values_for_attr("a").should == [1, 3]
    end
  end

  describe '#attributes' do
    it 'accepts symbols or strings interchangeably as strings' do
      o = TestEntity.new(:id => 'lol', :attributes => {"one" => 1, :two => 2})
      o.save!
      o.attributes["one"].should == 1
      o.attributes[:one].should == 1
      o.attributes["two"].should == 2
      o.attributes[:two].should == 2

      # Should also be true after reloading
      o = TestEntity.find 'lol'
      o.attributes["one"].should == 1
      o.attributes[:one].should == 1
      o.attributes["two"].should == 2
      o.attributes[:two].should == 2
    end
  end


  describe 'attribute description in the class definition' do

    it 'creates convenient accessor methods for accessing the attributes hash' do
      o = TestEntity.new
      class << o 
        attribute :colour
      end

      o.colour.should == nil
      o.colour = "red"
      o.colour.should == "red"
      o.attributes[:colour].should == "red"
    end

    it 'can set default values for attributes, with any ruby value for the default' do
      o = TestEntity.new

      # Change the singleton class for object o, this doesn't change the
      # TestEntity class
      class << o 
        attribute :size, :default => "medium"
        attribute :shape, :default => 2 
        attribute :style, :default => nil 
        attribute :teeth, :default => {"molars" => 4, "canines" => 2}
      end

      o.size.should == "medium"
      o.shape.should == 2
      o.style.should == nil
      o.teeth.should == {"molars" => 4, "canines" => 2}

      o.size = "large"
      o.size.should == "large"
    end

  end

  describe 'blob description in the class definition' do

    it 'creates convenient accessor methods for accessing the blobs hash' do
      o = TestEntity.new
      class << o 
        blob :avatar
      end

      o.avatar.should == nil

      o.avatar = "image_data_here"
      o.avatar.should == "image_data_here"
      o.tree[:avatar].should == "image_data_here"
    end

  end

  describe '.tree' do

    let(:record) do
      foo = TestEntity.dup
      foo.tree :foo
      foo.new
    end

    let(:tree) do
      { :x => 'blob', :y => { :z => 'blob' } }
    end

    it 'creates instance-level accessors' do
      record.should respond_to(:foo)
      record.should respond_to(:foo=)
    end

    it 'should return an empty HashWithIndifferentAccess by default via the instance-level getter' do
      record.foo.should == {}
      record.foo.should be_a HashWithIndifferentAccess
    end

    it 'should appropriately set and get via the accessors' do
      record.foo = tree

      # Check equivalency by comparing values of foo
      # A comparison cannot be made by record.foo == tree since
      # the setter converts tree to a HashWithIndifferentAccess
      record.foo['x'].should == tree[:x]
      record.foo['y']['z'].should == tree[:y][:z]
    end

    it 'should update the tree via the generated instance-level setter' do
      record.foo = tree
      record.tree['foo'].should == record.foo
    end

    it 'should provide scoped access to the tree via the generated instance-level getter' do
      record.foo['x'] = 'blob'
      record.foo['y'] = tree
      record.tree['foo']['x'].should == 'blob'
      record.tree['foo']['y']['x'].should == 'blob'
      record.tree['foo']['y']['y']['z'].should == 'blob'
    end

  end

end

