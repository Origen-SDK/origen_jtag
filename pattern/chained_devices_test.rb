
Pattern.create(options = { name: 'chained_devices_test' }) do

  jtag = $dut.jtag
  reg = $dut.reg(:full16)

  # set chained devices values
  jtag.chained_ir_lsb_length = 2
  jtag.chained_ir_lsb_data = 1
  jtag.chained_ir_msb_length = 3
  jtag.chained_ir_msb_data = 4
  
  jtag.chained_dr_lsb_length = 4
  jtag.chained_dr_lsb_data = 0xb
  jtag.chained_dr_msb_length = 5
  jtag.chained_dr_msb_data = 0x13

  cc 'ir write - TDI should be <100> 1111_1010 <01> - TDO should be <XXX> LHLH_HLHL <XX>'
  jtag.write_ir 0xFA, size: 8, shift_out_data: 0x5A

  cc 'ir read - TDI should be <100> 0000_0001 <01> - TDO should be <XXX> HLHL_LHLH <XX>'
  jtag.read_ir 0xA5, size: 8, shift_in_data: 1

  cc 'dr write - TDI should be <1_0011> 1111_1111_1111_1111 <1011> - TDO should be <X_XXXX> HLHL_LHLH_HLHL_LHLH <XXXX>'
  jtag.write_dr 0xFFFF, size: 16, shift_out_data: 0xA5A5

  cc 'dr read - TDI should be <1_0011> 0000_0000_0000_0000 <1011> - TDO should be <X_XXXX> LHLH_HLHL_LHLH_HLHL <XXXX>'
  jtag.read_dr 0x5A5A, size: 16

  cc 'TDI should be <1_0011> 1111_1111_1111_1111 <1011> - TDO should be <X_XXXX> XXXX_XXXX_HHHH_HHHH <XXXX>'
  reg.write(0xFFFF)
  reg.bits[0..7].read
  jtag.write_dr 0xFFFF, size: 16, shift_out_data: reg

  ss 'now with overlay and capture'
  if tester.uflex?
    tester.overlay_style = :digsrc
    tester.capture_style = :digcap
  end

  dut.full16.overlay 'dummy_str'
  cc 'TDI should be <1_0011> dddd_dddd_dddd_dddd <1011>'
  dut.jtag.write_dr dut.full16
  dut.full16.overlay nil
  dut.full16.store
  cc 'TDI should be <1_0011> 0000_0000_0000_0000 <1011> - TDO should be <X_XXXX> ssss_ssss_ssss_ssss <XXXX>'
  dut.jtag.read_dr dut.full16
end
