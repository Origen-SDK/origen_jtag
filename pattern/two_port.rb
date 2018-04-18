
Pattern.create(options = { name: 'two_port' }) do

  ss 'test using first jtag port'
  jtag = $dut.jtag
  reg = $dut.reg(:full16)

  cc 'TDO should be HLHL_LHLH_HLHL_LHLH'
  jtag.write_dr 0xFFFF, size: 16, shift_out_data: 0xA5A5

  cc 'TDO should be XXXX_XXXX_HHHH_HHHH'
  reg.write(0xFFFF)
  reg.bits[0..7].read
  jtag.write_dr 0xFFFF, size: 16, shift_out_data: reg


  cc 'TDO should be HLHL_LHLH_HLHL_LHLH'
  reg.write(0xFFFF)
  jtag.write_dr reg, shift_out_data: 0xA5A5

  cc 'TDO should be XXXX_XXXX_HHHH_HHHH'
  reg.write(0xFFFF)
  reg2 = reg.dup
  reg2.bits[0..7].read
  jtag.write_dr reg, size: 16, shift_out_data: reg2

  
  ss 'test using second jtag port'
  jtag = $dut.jtag2

  cc 'TDO should be HLHL_LHLH_HLHL_LHLH'
  jtag.write_dr 0xFFFF, size: 16, shift_out_data: 0xA5A5

  cc 'TDO should be XXXX_XXXX_HHHH_HHHH'
  reg.write(0xFFFF)
  reg.bits[0..7].read
  jtag.write_dr 0xFFFF, size: 16, shift_out_data: reg


  cc 'TDO should be HLHL_LHLH_HLHL_LHLH'
  reg.write(0xFFFF)
  jtag.write_dr reg, shift_out_data: 0xA5A5

  cc 'TDO should be XXXX_XXXX_HHHH_HHHH'
  reg.write(0xFFFF)
  reg2 = reg.dup
  reg2.bits[0..7].read
  jtag.write_dr reg, size: 16, shift_out_data: reg2
end
