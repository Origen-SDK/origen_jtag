require 'spec_helper'

describe 'JTAG Driver Specification' do

  before :all do
    Origen.environment.temporary = 'j750.rb'
  end

  it 'JTAG Configuration can be declared at DUT creation' do 
    load_target('RL4.rb')

    # verify specified configuration
    dut.tclk_format.should == :rl
    dut.tclk_multiple.should == 4
    dut.tdo_strobe.should == :tclk_high
    dut.tdo_store_cycle.should == 3
    dut.init_state.should == :unknown
  end

  it 'JTAG Configuration can be changed post-DUT-creation' do
    load_target('RH1.rb')
    dut.tclk_format.should == :rh                 # check initial settings
    dut.update_jtag_config(:tclk_format, :rl)     # update configuration   
    dut.tclk_format.should == :rl                 # verify updates
  end

  it "Trying to update invalid config type results in error" do
    load_target('RL1.rb')
    lambda { dut.update_jtag_config(:invalid_config, 22) }.should raise_error
  end

  it 'JTAG TCLK format is invalid' do
    load_target('RL1.rb')
    dut.update_jtag_config(:tclk_format, :nrz)
    lambda { dut.jtag.tclk_cycle }.should raise_error
  end

  it 'JTAG State can be queried' do
    load_target('RH1.rb')
    dut.startup
    dut.jtag.idle
    dut.jtag.state_str.should == "Run-Test/Idle"

    dut.jtag.pause_dr do
      dut.jtag.state_str.should == "Pause-DR"
    end
  end

  it 'TCLK multiple can be queried' do
    load_target('RL4.rb')
    dut.jtag.tclk_multiple.should == 4
  end

  it 'Raises error when used with invalid pins' do
    lambda {
      load_target('invalid_pins')
      dut.jtag.pause_dr do
      end
    }.should raise_error
  end

  it 'maintains access to tclk_cycle method' do
    load_target('RL4.rb')
    dut.jtag.respond_to?(:tclk_cycle).should == true
  end

  it 'tdo_store_cycle and tdo_strobe can be accessed' do
    load_target('RL4.rb')
    dut.jtag.tdo_store_cycle.should == 3
    dut.jtag.tdo_store_cycle = 2
    dut.jtag.tdo_store_cycle.should == 2

    dut.jtag.tdo_strobe.should == :tck_high
    dut.jtag.tdo_strobe = :tck_low
    dut.jtag.tdo_strobe.should == :tck_low
  end

end
