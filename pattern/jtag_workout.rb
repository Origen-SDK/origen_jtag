pat_name = "jtag_workout_#{$dut.tclk_format.upcase}#{$dut.tclk_multiple}"
pat_name = pat_name + "_#{dut.tdo_store_cycle}" if dut.tdo_store_cycle != 0
pat_name += "_serial" if dut.is_a?(OrigenJTAGDev::Serial)
pat_name += "_tclk_vals" if dut.try(:tclk_vals)

Pattern.create(options = { name: pat_name }) do
  def test(msg)
    ss "Test - #{msg}"
  end

  jtag = $dut.jtag
  reg = $dut.reg(:test16)

  # First tests of the TAP Controller

  test 'Transition TAP controller in and out of Shift-DR'
  jtag.shift_dr {}

  test 'Transition TAP controller in and out of Pause-DR'
  jtag.pause_dr {}

  test 'Transition TAP controller in and out of Shift-IR'
  jtag.shift_ir {}

  test 'Transition TAP controller in and out of Pause-IR'
  jtag.pause_ir {}

  test 'Transition into Shift-DR, then back and forth into Pause-DR'
  jtag.shift_dr do
    jtag.pause_dr {}
    jtag.pause_dr {}
  end

  test 'Transition into Pause-DR, then back and forth into Shift-DR'
  jtag.pause_dr do
    jtag.shift_dr {}
    jtag.shift_dr {}
  end

  test 'Transition into Shift-IR, then back and forth into Pause-IR'
  jtag.shift_ir do
    jtag.pause_ir {}
    jtag.pause_ir {}
  end

  test 'Transition into Pause-IR, then back and forth into Shift-IR'
  jtag.pause_ir do
    jtag.shift_ir {}
    jtag.shift_ir {}
  end

  # Tests of the shift method, make sure it handles registers with
  # bit-level flags set in additional to dumb values

  test 'Shifting an explicit value into TDI'
  jtag.shift 0x1234, size: 16, cycle_last: true

  test 'Shifting an explicit value out of TDO'
  jtag.shift 0x1234, size: 16, cycle_last: true, read: true

  test 'Shift register into TDI'
  reg.write(0xFF01)
  cc 'Full register (16 bits)'
  jtag.shift reg, cycle_last: true
  cc 'Full register with additional size (32 bits)'
  jtag.shift reg, cycle_last: true, size: 32
  cc 'Full register with reduced size (8 bits)'
  jtag.shift reg, cycle_last: true, size: 8, includes_last_bit: false

  test 'Shift register into TDI with overlay'
  reg.overlay('write_overlay')
  cc 'Full register (16 bits)'
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true
  cc 'Full register with additional size (32 bits)'
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true, size: 32
  cc 'Full register with reduced size (8 bits)'
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true, size: 8, includes_last_bit: false
  cc 'It should in-line overlays when running in simulation mode'
  Origen.mode = :simulation
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true
  Origen.mode = :debug
  if tester.respond_to?('label')
    cc 'Full register overlay without using subroutine'
    jtag.shift reg, cycle_last: true, no_subr: true
  end

  test 'Shift register into TDI with single bit overlay'
  reg.overlay(nil)
  reg.bit(:bit).overlay('write_overlay2')
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true
  reg.overlay(nil)

  test 'Read register out of TDO'
  cc 'Full register (16 bits)'
  reg.read
  jtag.shift reg, cycle_last: true, read: true
  cc 'Full register with additional size (32 bits)'
  reg.read
  jtag.shift reg, cycle_last: true, size: 32, read: true
  cc 'Full register with reduced size (8 bits)'
  reg.read
  jtag.shift reg, cycle_last: true, size: 8, read: true, includes_last_bit: false

  test 'Read single bit out of TDO'
  reg.bit(:bit).read
  jtag.shift reg, cycle_last: true, read: true

  test 'Store register out of TDO'
  cc 'Full register (16 bits)'
  reg.store
  jtag.shift reg, cycle_last: true, read: true
  cc 'Full register with additional size (32 bits)'
  reg.store
  jtag.shift reg, cycle_last: true, size: 32, read: true
  cc 'Full register with reduced size (8 bits)'
  reg.store
  jtag.shift reg, cycle_last: true, size: 8, read: true, includes_last_bit: false

  test 'Store single bit out of TDO'
  reg.bit(:bit).store
  jtag.shift reg, cycle_last: true, read: true

  test 'Test flag clear, bit 0 should be read, but not stored'
  reg.bit(:bit).read
  jtag.shift reg, cycle_last: true, read: true

  test 'Shift register out of TDO with overlay'
  reg.overlay('read_overlay')
  cc 'Full register (16 bits)'
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true, read: true
  cc 'Full register with additional size (32 bits)'
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true, size: 32, read: true
  cc 'Full register with reduced size (8 bits)'
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true, size: 8, read: true, includes_last_bit: false
  cc 'It should in-line overlays when running in simulation mode'
  Origen.mode = :simulation
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true, read: true
  Origen.mode = :debug
  if tester.respond_to?('label')
    cc 'Full register overlay without using subroutine'
    jtag.shift reg, cycle_last: true, read: true, no_subr: true
  end

  test 'Shift register out of TDO with single bit overlay'
  reg.overlay(nil)
  reg.bit(:bit).overlay('read_overlay2')
  tester.cycle  # Give a padding cycle as a place for the subroutine call to go
  jtag.shift reg, cycle_last: true
  reg.overlay(nil)

  # Finally integration tests of the TAPController + shift

  test 'Write value into DR'
  jtag.write_dr 0xFFFF, size: 16, msg: 'Write value into DR'

  test 'Write value into DR, with compare on TDO'
  jtag.write_dr 0xFFFF, size: 16, shift_out_data: 0xAAAA, msg: 'Write value into DR'

   test 'Write register into DR with full-width overlay'
  r = $dut.reg(:test32)
  r.overlay('write_overlay')
  jtag.write_dr r
  r.overlay(nil)

  test 'Read value out of DR'
  jtag.read_dr 0xFFFF, size: 16, msg: 'Read value out of DR'

  test 'Store value out of DR'
  r.store
  jtag.read_dr r


  test 'Read value out of DR, with specified shift in data into TDI'
  jtag.read_dr 0xFFFF, size: 16, shift_in_data: 0x5555, msg: 'Read value out of DR'

   test 'Write value into IR'
  jtag.write_ir 0xF, size: 4, msg: 'Write value into IR'

  test 'Read value out of IR'
  jtag.read_ir 0xF, size: 4, msg: 'Read value out of IR'

  test 'The IR value is tracked and duplicate writes are inhibited'
  jtag.write_ir 0xF, size: 4

  test 'Unless forced'
  jtag.write_ir 0xF, size: 4, force: true

  test 'Write IR, starting with Idle, leave in Select-DR-Scan state'
  jtag.write_ir(0x7, size: 8, end_state: :select_dr_scan, force: true)

  test 'Write DR starting with Select-DR-Scan state, end with Idle'
  jtag.write_dr(0x12345678, size: 32, start_state: :select_dr_scan)

  test 'Reset'
  jtag.reset

  if dut.has_pin?(:tdo)
    test 'Suspend of compare on TDO works'
    cc 'TDO should be H'
    jtag.read_dr 0xFFFF, size: 16, msg: 'Read value out of DR'
    tester.ignore_fails($dut.pin(:tdo)) do
      cc 'TDO should be X'
      jtag.read_dr 0xFFFF, size: 16, msg: 'Read value out of DR'
    end
    cc 'TDO should be H'
    jtag.read_dr 0xFFFF, size: 16, msg: 'Read value out of DR'
  end

  test 'Mask option for read_dr works'
  cc 'TDO should be H'
  jtag.read_dr 0xFFFF, size: 16, mask: 0x5555, msg: 'Read value out of DR'

  test 'Write value into DR, with compare on TDO'
  jtag.write_dr 0x5555, size: 16, shift_out_data: 0xAAAA, mask: 0x00FF, msg: 'Write value into DR'

  test 'Shifting an explicit value out of TDO with mask'
  jtag.shift 0x1234, size: 16, read: true, mask: 0xFF00

  test 'Shifting an explicit value into TDI (and out of TDO)'
  jtag.shift 0x1234, size: 16, cycle_last: true, shift_out_data: 0xAAAA, mask: 0x0F0F
end
