Pattern.create do
  def test(msg)
    ss "Test - #{msg}"
  end

  jtag = $dut.jtag
  reg = $dut.reg(:test16)

  # First tests of the TAP Controller

  test "Transition TAP controller in and out of Shift-DR"
  jtag.shift_dr { }

  test "Transition TAP controller in and out of Pause-DR"
  jtag.pause_dr { }

  test "Transition TAP controller in and out of Shift-IR"
  jtag.shift_ir { }

  test "Transition TAP controller in and out of Pause-IR"
  jtag.pause_ir { }

  test "Transition into Shift-DR, then back and forth into Pause-DR"
  jtag.shift_dr do
    jtag.pause_dr { }
    jtag.pause_dr { }
  end

  test "Transition into Pause-DR, then back and forth into Shift-DR"
  jtag.pause_dr do
    jtag.shift_dr { }
    jtag.shift_dr { }
  end
  
  test "Transition into Shift-IR, then back and forth into Pause-IR"
  jtag.shift_ir do
    jtag.pause_ir { }
    jtag.pause_ir { }
  end

  test "Transition into Pause-IR, then back and forth into Shift-IR"
  jtag.pause_ir do
    jtag.shift_ir { }
    jtag.shift_ir { }
  end

  # Tests of the shift method, make sure it handles registers with
  # bit-level flags set in additional to dumb values

  test "Shifting an explicit value into TDI"
  jtag.shift 0x1234, :size => 16, :cycle_last => true

  test "Shifting an explicit value out of TDO"
  jtag.shift 0x1234, :size => 16, :cycle_last => true, :read => true

  test "Shift register into TDI"
    reg.write(0xFF01)
    cc "Full register (16 bits)"
    jtag.shift reg, :cycle_last => true
    cc "Full register with additional size (32 bits)"
    jtag.shift reg, :cycle_last => true, :size => 32
    cc "Full register with reduced size (8 bits)"
    jtag.shift reg, :cycle_last => true, :size => 8

  test "Shift register into TDI with overlay"
    reg.overlay("write_overlay")
    cc "Full register (16 bits)"
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true
    cc "Full register with additional size (32 bits)"
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true, :size => 32
    cc "Full register with reduced size (8 bits)"
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true, :size => 8
    cc "It should in-line overlays when running in simulation mode"
    RGen.mode = :simulation
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true
    RGen.mode = :debug

  test "Shift register into TDI with single bit overlay"
    reg.overlay(nil)
    reg.bit(:bit).overlay("write_overlay")
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true
    reg.overlay(nil)

  test "Read register out of TDO"
    cc "Full register (16 bits)"
    reg.read
    jtag.shift reg, :cycle_last => true, :read => true
    cc "Full register with additional size (32 bits)"
    reg.read
    jtag.shift reg, :cycle_last => true, :size => 32, :read => true
    cc "Full register with reduced size (8 bits)"
    reg.read
    jtag.shift reg, :cycle_last => true, :size => 8, :read => true

  test "Read single bit out of TDO"
    reg.bit(:bit).read
    jtag.shift reg, :cycle_last => true, :read => true

  test "Store register out of TDO"
    cc "Full register (16 bits)"
    reg.store
    jtag.shift reg, :cycle_last => true, :read => true
    cc "Full register with additional size (32 bits)"
    reg.store
    jtag.shift reg, :cycle_last => true, :size => 32, :read => true
    cc "Full register with reduced size (8 bits)"
    reg.store
    jtag.shift reg, :cycle_last => true, :size => 8, :read => true

  test "Store single bit out of TDO"
    reg.bit(:bit).store
    jtag.shift reg, :cycle_last => true, :read => true

  test "Test flag clear, bit 0 should be read, but not stored"
    reg.bit(:bit).read
    jtag.shift reg, :cycle_last => true, :read => true

  test "Shift register out of TDO with overlay"
    reg.overlay("read_overlay")
    cc "Full register (16 bits)"
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true, :read => true
    cc "Full register with additional size (32 bits)"
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true, :size => 32, :read => true
    cc "Full register with reduced size (8 bits)"
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true, :size => 8, :read => true
    cc "It should in-line overlays when running in simulation mode"
    RGen.mode = :simulation
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true, :read => true
    RGen.mode = :debug

  test "Shift register out of TDO with single bit overlay"
    reg.overlay(nil)
    reg.bit(:bit).overlay("read_overlay")
    RGen.tester.cycle  # Give a padding cycle as a place for the subroutine call to go
    jtag.shift reg, :cycle_last => true
    reg.overlay(nil)

  # Finally integration tests of the TAPController + shift

  test "Write value into DR"
    jtag.write_dr 0xFFFF, :size => 16

  test "Read value out of DR"
    jtag.read_dr 0xFFFF, :size => 16

  test "Write value into IR"
    jtag.write_ir 0xF, :size => 4

  test "Read value out of IR"
    jtag.read_ir 0xF, :size => 4

  test "The IR value is tracked and duplicate writes are inhibited"
    jtag.write_ir 0xF, :size => 4

  test "Unless forced"
    jtag.write_ir 0xF, :size => 4, :force => true
end
