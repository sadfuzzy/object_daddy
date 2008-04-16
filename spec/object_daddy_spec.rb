require File.dirname(__FILE__) + '/spec_helper'
require 'ostruct'
require 'object_daddy'

describe ObjectDaddy, "when included into a class" do
  before(:each) do
    @class = Class.new
    @class.send(:include, ObjectDaddy)
  end
  
  it "should provide a means of spawning a class instance" do
    @class.should respond_to(:spawn)
  end
  
  it "should not provide a means of generating and saving a class instance" do
    @class.should_not respond_to(:generate)
  end
  
  it "should not provide a means of generating and saving a class instance while raising exceptions" do
    @class.should_not respond_to(:generate!)
  end
  
  it "should provide a means of registering a generator to assist in creating class instances" do
    @class.should respond_to(:generator_for)
  end
end

describe ObjectDaddy, "when registering a generator method" do
  before(:each) do
    @class = Class.new(OpenStruct)
    @class.send(:include, ObjectDaddy)
  end
  
  it "should fail unless an attribute name is provided" do
    lambda { @class.generator_for }.should raise_error(ArgumentError)
  end
  
  it "should fail if an attribute is specified that already has a generator" do
    @class.generator_for :foo do |prev| end
    lambda { @class.generator_for :foo do |prev| end }.should raise_error(ArgumentError)
  end
  
  it "should be agnostic to attribute names specified as symbols or strings" do
    @class.generator_for :foo do |prev| end
    lambda { @class.generator_for 'foo' do |prev| end }.should raise_error(ArgumentError)
  end
  
  it "should keep generators registered for different target classes separate" do
    @class2 = Class.new
    @class2.send :include, ObjectDaddy
    @class2.generator_for :foo do |prev| end
    lambda { @class.generator_for 'foo' do |prev| end }.should_not raise_error
  end

  it "should succeed if a generator block is provided" do
    lambda { @class.generator_for :foo do |prev| end }.should_not raise_error
  end
  
  it "should not fail if a generator block doesn't handle a previous value" do
    lambda { @class.generator_for :foo, :first => 'baz' do end }.should_not raise_error(ArgumentError)
  end
  
  it "should not fail if a generator block specifically doesn't handle a previous value" do
    lambda { @class.generator_for :foo, :first => 'baz' do || end }.should_not raise_error(ArgumentError)
  end
  
  it "should fail if a generator block expects more than one argument" do
    lambda { @class.generator_for :foo, :first => 'baz' do |x, y| end }.should raise_error(ArgumentError)
  end
  
  it "should allow an initial value with a block argument" do
    lambda { @class.generator_for :foo, :start => 'baz' do |prev| end }.should_not raise_error
  end
  
  it "should succeed if a generator class is provided" do
    @generator = Class.new
    @generator.stubs(:next)
    lambda { @class.generator_for :foo, :class => @generator }.should_not raise_error
  end
  
  it "should fail if a generator class is specified which doesn't have a next method" do
    @generator = Class.new
    lambda { @class.generator_for :foo, :class => @generator }.should raise_error(ArgumentError)
  end

  it "should succeed if a generator method name is provided" do
    @class.stubs(:method_name)
    lambda { @class.generator_for :foo, :method => :method_name }.should_not raise_error    
  end
  
  it "should fail if a non-existent generator method name is provided" do
    lambda { @class.generator_for :foo, :method => :fake_method }.should raise_error(ArgumentError)
  end
  
  it 'should succeed if a value is provided' do
    lambda { @class.generator_for :foo, 'value' }.should_not raise_error(ArgumentError)
  end
  
  it 'should succeed when given an attr => value hash' do
    lambda { @class.generator_for :foo => 'value' }.should_not raise_error(ArgumentError)
  end
  
  it 'should fail when given an attr => value hash with multiple attrs' do
    lambda { @class.generator_for :foo => 'value', :bar => 'other value' }.should raise_error(ArgumentError)
  end
  
  it "should fail unless a generator block, generator class, generator method, or value is provided" do
    lambda { @class.generator_for 'foo' }.should raise_error(ArgumentError)
  end
end

describe ObjectDaddy, 'recording the registration of a generator method' do
  before(:each) do
    ObjectDaddy::ClassMethods.send(:public, :record_generator_for)
    @class = Class.new(OpenStruct)
    @class.send(:include, ObjectDaddy)
  end
  
  it 'should accept a handle and generator' do
    lambda { @class.record_generator_for('handle', 'generator') }.should_not raise_error(ArgumentError)
  end
  
  it 'should require generator' do
    lambda { @class.record_generator_for('handle') }.should raise_error(ArgumentError)
  end
  
  it 'should require a handle' do
    lambda { @class.record_generator_for }.should raise_error(ArgumentError)
  end
  
  it 'should save the generator' do
    @class.record_generator_for('handle', 'generator')
    @class.generators['handle'][:generator].should == 'generator'
  end
  
  it 'should save the class that specified the generator' do
    @class.record_generator_for('handle', 'generator')
    @class.generators['handle'][:source].should == @class
  end
  
  it 'should fail if the handle has already been recorded' do
    @class.record_generator_for('handle', 'generator')
    lambda { @class.record_generator_for('handle', 'generator 2') }.should raise_error
  end
  
  it 'should not fail if the handle has not already been recorded' do
    lambda { @class.record_generator_for('handle', 'generator') }.should_not raise_error
  end
end

describe ObjectDaddy, "when spawning a class instance" do
  before(:each) do
    @class = Class.new(OpenStruct)
    @class.send(:include, ObjectDaddy)
    @file_path = File.join(File.dirname(__FILE__), 'tmp')
    @file_name = File.join(@file_path, 'widget_exemplar.rb')
    @class.stubs(:exemplar_path).returns(@file_path)
    @class.stubs(:name).returns('Widget')
  end
  
  it "should register exemplars for the target class on the first attempt" do
    @class.expects(:gather_exemplars)
    @class.spawn
  end
  
  it "should not register exemplars for the target class after the first attempt" do
    @class.spawn
    @class.expects(:gather_exemplars).never
    @class.spawn
  end

  it "should look for exemplars for the target class in the standard exemplar path" do
    @class.expects(:exemplar_path).returns(@file_path)
    @class.spawn
  end
  
  it "should look for an exemplar for the target class, based on the class's name" do
    @class.expects(:name).returns('Widget')
    @class.spawn
  end
  
  it "should register any generators found in the exemplar for the target class" do 
    # we are using the concrete Widget class here because otherwise it's difficult to have our exemplar file work in our class
    begin
      # a dummy class, useful for testing the actual loading of exemplar files
      Widget = Class.new(OpenStruct) { include ObjectDaddy }
      File.open(@file_name, 'w') {|f| f.puts "class Widget\ngenerator_for :foo\nend\n"}
      Widget.stubs(:exemplar_path).returns(@file_path)
      Widget.expects(:generator_for)
      Widget.spawn
    ensure
      # clean up test data file
      File.unlink(@file_name) if File.exists?(@file_name)
    end
  end
  
  it "should register no generators if no exemplar for the target class is available" do
    @class.expects(:generator_for).never
    @class.spawn
  end
  
  it "should allow attributes to be overridden" do
    @class.spawn(:foo => 'xyzzy').foo.should == 'xyzzy'
  end
  
  it "should use any generators registered with blocks" do
    @class.generator_for :foo do |prev| "foo"; end
    @class.spawn.foo.should == 'foo'
  end
  
  it "should not use a block generator for an attribute that has been overridden" do
    @class.generator_for :foo do |prev| "foo"; end
    @class.spawn(:foo => 'xyzzy').foo.should == 'xyzzy'
  end
  
  it "should use any generators registered with generator method names" do
    @class.stubs(:generator_method).returns('bar')
    @class.generator_for :foo, :method => :generator_method
    @class.spawn.foo.should == 'bar'
  end
  
  it "should not use a method generator for an attribute that has been overridden" do
    @class.stubs(:generator_method).returns('bar')
    @class.generator_for :foo, :method => :generator_method
    @class.spawn(:foo => 'xyzzy').foo.should == 'xyzzy'
  end
  
  it "should use any generators registered with generator classes" do
    @generator_class = Class.new do
      def self.next() 'baz' end
    end
    @class.generator_for :foo, :class => @generator_class
    @class.spawn.foo.should == 'baz'
  end

  it "should not use a class generator for an attribute that has been overridden" do
    @generator_class = Class.new do
      def self.next() 'baz' end
    end
    @class.generator_for :foo, :class => @generator_class
    @class.spawn(:foo => 'xyzzy').foo.should == 'xyzzy'
  end
  
  it "should return the initial value first if one was registered for a block generator" do
    @class.generator_for :foo, :start => 'frobnitz' do |prev| "foo"; end
    @class.spawn.foo.should == 'frobnitz'
  end
  
  it "should return the block applied to the initial value on the second call if an initial value was registered for a block generator" do
    @class.generator_for :foo, :start => 'frobnitz' do |prev| prev.succ; end
    @class.spawn
    @class.spawn.foo.should == 'frobniua'
  end
  
  it "should return the block applied to the previous value when repeatedly calling a block generator" do
    @class.generator_for :foo do |prev| prev ? prev.succ : 'test'; end
    @class.spawn
    @class.spawn.foo.should == 'tesu'
  end
  
  it 'should use the return value for a block generator that takes no argument' do
    x = 5
    @class.generator_for(:foo) { x }
    @class.spawn.foo.should == x
  end
  
  it 'should use the return value for a block generator that explicitly takes no argument' do
    x = 5
    @class.generator_for(:foo) { ||  x }
    @class.spawn.foo.should == x
  end
  
  it 'should use the supplied value for the generated value' do
    x = 5
    @class.generator_for :foo, x
    @class.spawn.foo.should == x
  end
  
  it 'should use the supplied attr => value value for the generated value' do
    x = 5
    @class.generator_for :foo => x
    @class.spawn.foo.should == x
  end
  
  it "should call the normal target class constructor" do
    @class.expects(:new)
    @class.spawn
  end
  
  describe 'for a subclass' do
    before :each do
      @subclass = Class.new(@class)
      @subclass.send(:include, ObjectDaddy)
      @subfile_path = File.join(File.dirname(__FILE__), 'tmp')
      @subfile_name = File.join(@file_path, 'sub_widget_exemplar.rb')
      @subclass.stubs(:exemplar_path).returns(@file_path)
      @subclass.stubs(:name).returns('SubWidget')
    end
    
    describe 'using generators from files' do
      before :each do
        # FIXME: get rid of 'already initialized constant' warnings
        Widget = Class.new(OpenStruct) { include ObjectDaddy }
        SubWidget = Class.new(Widget)  { include ObjectDaddy }
        
        Widget.stubs(:exemplar_path).returns(@file_path)
        SubWidget.stubs(:exemplar_path).returns(@subfile_path)
        
        File.open(@file_name, 'w') do |f|
          f.puts "class Widget\ngenerator_for :blah do |prev| 'blah'; end\nend\n"
        end
      end
      
      after :each do
        [@file_name, @subfile_name].each { |file|  File.unlink(file) if File.exists?(file) }
      end
      
      it 'should use generators from the parent class' do
        SubWidget.spawn.blah.should == 'blah'
      end
      
      it 'should let subclass generators override parent generators' do
        File.open(@subfile_name, 'w') do |f|
          f.puts "class SubWidget\ngenerator_for :blah do |prev| 'blip'; end\nend\n"
        end
        SubWidget.spawn.blah.should == 'blip'
      end
    end
    
    describe 'using generators called directly' do
      it 'should use generators from the parent class' do
        @class.generator_for :blah do |prev| 'blah'; end
        @subclass.spawn.blah.should == 'blah'
      end
      
      it 'should let subclass generators override parent generators' do
        pending 'figuring out what to do about this, including deciding whether or not this is even important' do
          @class.generator_for :blah do |prev| 'blah'; end
          # p @class
          # p @subclass
          # @subclass.send(:gather_exemplars)
          # p @subclass.generators
          @subclass.generator_for :blah do |prev| 'blip'; end
          # @subclass.send(:gather_exemplars)
          # p @subclass.generators
          # p @subclass.generators[:blah][:generator][:block].call
          # @subclass.send(:gather_exemplars)
          @subclass.spawn.blah.should == 'blip'
        end
      end
    end
  end
end

# conditionally do Rails tests, if we were included as a plugin
if File.exists?("#{File.dirname(__FILE__)}/../../../../config/environment.rb")

  setup_rails_database

  class Foo < ActiveRecord::Base
  end
  
  class Bar < ActiveRecord::Base
  end
  
  class Thing < ActiveRecord::Base
  end

  class Frobnitz < ActiveRecord::Base
    belongs_to :foo
    belongs_to :bar
    belongs_to :thing
    validates_presence_of :foo
    validates_presence_of :thing_id
    validates_presence_of :name
    validates_presence_of :title, :on => :create, :message => "can't be blank"
    validates_format_of   :title, :with => /^\d+$/
  end
  
  class Blah < ActiveRecord::Base
  end

  describe ObjectDaddy, "when integrated with Rails" do
    it "should provide a means of generating and saving a class instance" do
      Frobnitz.should respond_to(:generate)
    end
    
    it "should provide a means of generating and saving a class instance while raising exceptions" do
      Frobnitz.should respond_to(:generate!)
    end
    
    it "should base the exemplar path off RAILS_ROOT for ActiveRecord models" do
      Frobnitz.exemplar_path.should == File.join(RAILS_ROOT, 'test', 'exemplars')
    end
    
    it "should generate instances of any belongs_to associations which are required by a presence_of validator for the association name" do
      foo = Foo.create(:name => 'some foo')
      Foo.expects(:generate).returns(foo)
      Frobnitz.spawn
    end
    
    it "should generate and save instances of any belongs_to associations which are required by a presence_of validator for the association ID" do
      thing = Thing.create(:name => 'some thing')
      Thing.expects(:generate).returns(thing)
      Frobnitz.spawn
    end
    
    it "should not generate instances of belongs_to associations which are not required by a presence_of validator" do
      Bar.expects(:generate).never
      Frobnitz.spawn
    end
    
    it "should not generate any values for attributes that do not have generators" do
      Frobnitz.spawn.name.should be_nil
    end

    it "should use specified values for attributes that do not have generators" do
      Frobnitz.spawn(:name => 'test').name.should == 'test'
    end
    
    it "should use specified values for attributes that would otherwise be generated" do
      Foo.expects(:generate).never
      foo = Foo.new
      Frobnitz.spawn(:foo => foo).foo.should == foo
    end
    
    # NOTE: This could be better with validation reflection
    it 'should pass the supplied validator options to the real validator method' do
      Blah.expects(:validates_presence_of_without_object_daddy).with(:bam, :if => :make_it_so)
      Blah.validates_presence_of :bam, :if => :make_it_so
    end
    
    # what is this testing?
    it "should ignore optional arguments to presence_of validators" do
      Frobnitz.should have(4).presence_validated_attributes
    end
    
    it "should return an unsaved record if spawning" do
      Thing.spawn.should be_new_record
    end
    
    it "should return a saved record if generating" do
      Thing.generate.should_not be_new_record
    end
    
    it 'should return a saved record if generating while raising exceptions' do
      Thing.generate!.should_not be_new_record
    end
    
    it "should not fail if trying to generate and save an invalid object" do
      lambda { Frobnitz.generate(:title => 'bob') }.should_not raise_error(ActiveRecord::RecordInvalid)
    end
    
    it "should return an invalid object if trying to generate and save an invalid object" do
      Frobnitz.generate(:title => 'bob').should_not be_valid
    end
    
    it "should fail if trying to generate and save an invalid object while raising acceptions" do
      lambda { Frobnitz.generate!(:title => 'bob') }.should raise_error(ActiveRecord::RecordInvalid)
    end
    
    it "should return a valid object if generate and save succeeds" do
      Frobnitz.generate(:title => '5', :name => 'blah').should be_valid
    end
  end
end
