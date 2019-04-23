module OrigenJTAGDev
  # This is a dummy DUT model which is used
  # to instantiate and test the JTAG locally
  # during development.
  #
  # It is not included when this library is imported.
  class Serial < NewStyle
    def instantiate_pins(options = {})
      add_pin :tck
      add_pin :tio
    end

    def jtag_cycle(actions, options = {})
      pin(:tck).drive(1)
      jtag.apply_action(pin(:tio), actions[:tdi])
      tester.cycle(options)
      jtag.apply_action(pin(:tio), actions[:tms])
      tester.cycle(options)
      jtag.apply_action(pin(:tio), actions[:tdo])
      tester.store_next_cycle(pin(:tio)) if actions[:store]
      tester.cycle(options)
    end
  end
end
