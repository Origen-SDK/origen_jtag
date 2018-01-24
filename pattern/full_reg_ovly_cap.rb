if tester.uflex?
  Pattern.create do
    tester.overlay_style = :digsrc
    dut.full16.overlay 'dummy_str'
    dut.jtag.write_dr dut.full16

    tester.capture_style = :digcap
    dut.full16.overlay nil
    dut.full16.store
    dut.jtag.read_dr dut.full16
  end
end