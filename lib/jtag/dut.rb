module JTAG
  # This is a dummy DUT model which is used
  # to instantiate and test the JTAG locally
  # during development.
  #
  # It is not included when this library is imported.
  class DUT

    include JTAG
    include RGen::Callbacks
    include RGen::Registers
    include RGen::Pins

    JTAG_CONFIG = {
      :verbose => true,
    }

    def on_create
      add_reg :test16, 0x0012, 16, :bus => {pos: 8, bits: 8},
                                   :bit => {pos: 0 }

      $tester.set_timeset("nvmbist", 40) 
      add_pin :tclk
      add_pin :tdi
      add_pin :tdo
      add_pin :tms
    end
  
  end
end
