require File.expand_path(File.join(File.dirname(__FILE__), '/../helper'))

describe Tickleby::SetCommand do
  
  before(:each) do
    @interp = Tickleby::Interp.new
    @command = @interp.commands["set"]
  end

  it "should set first argument to second argument in parent stack frame" do
    frame = @interp.stack[-1]
    result = ''
    @interp.with_new_frame do 
      result = @command.call @interp, ['a', 'b']
    end
    frame.get_variable('a').should == 'b'
    result.should == 'b'
  end

  it "should return variables value when called with one argument" do
    @interp.stack[-1].set_variable('c', 'hello')
    result = ''
    @interp.with_new_frame do
      result = @command.call @interp, ['c']
    end
    result.should == 'hello'
  end
end

describe Tickleby::GlobalCommand do
  before(:each) do
    @interp = Tickleby::Interp.new
  end

  it "should have no affect if not executed in a proc body" do
    @interp.eval("global x")

    lambda {@interp.stack[-1].get_variable("x")}.should raise_error
  end

  it "should create a local variable linked to a global variable in proc scope" do

    @interp.eval("proc test {} { 
          global x y
          set x 99
          set y 100
        }
        test
    ")
    @interp.get_global("x").should == "99"
    @interp.get_global("y").should == "100"
  end
  
end

describe Tickleby::ReturnCommand do
  
  before(:each) do
    @interp = Tickleby::Interp.new
    @command = @interp.commands["return"]
  end

  it "should return its first argument" do
    result = ''
    @interp.with_new_frame do
      result = @command.call @interp, ['value']
    end
    result.should == 'value'
  end

  it "should return an empty string if given no arguments" do
    result = 'something'
    @interp.with_new_frame do
      result = @command.call @interp, []
    end
    result.should == ''
  end

  it "should set the return flag to :return" do
    @interp.with_new_frame do
      @command.call @interp, []
    end
    @interp.return_flag.should == :return
  end

end
