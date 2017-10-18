if tester.j750? || tester.uflex?
  Pattern.create(options = { name: 'global_label_test' }) do

    jtag = $dut.jtag
    reg = $dut.reg(:full16)

    cc 'TDO should be HLHL_LHLH_HLHL_LHLH'
    reg.write(0xFFFF)
    reg.overlay('globaltest')
    jtag.write_dr reg, overlay: true, overlay_label: 'thisisthegloballabel'

  end
end