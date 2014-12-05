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
      verbose:         true,
      tclk_format:     :rh,
      tclk_multiple:   1,
      tdo_strobe:      :tclk_high,
      tdo_store_cycle: 0,
      init_state:      :unknown
    }

    def initialize(options = {})
      JTAG_CONFIG[:tclk_format] = options[:tclk_format] if options[:tclk_format]
      JTAG_CONFIG[:tclk_multiple] = options[:tclk_multiple] if options[:tclk_multiple]
      JTAG_CONFIG[:tdo_strobe] = options[:tdo_strobe] if options[:tdo_strobe]
      JTAG_CONFIG[:tdo_store_cycle] = options[:tdo_store_cycle] if options[:tdo_store_cycle]
      JTAG_CONFIG[:init_state] = options[:init_state] if options[:init_state]
    end

    def tclk_format
      JTAG_CONFIG[:tclk_format]
    end

    def tclk_multiple
      JTAG_CONFIG[:tclk_multiple]
    end

    def tdo_strobe
      JTAG_CONFIG[:tdo_strobe]
    end

    def tdo_store_cycle
      JTAG_CONFIG[:tdo_store_cycle]
    end

    def init_state
      JTAG_CONFIG[:init_state]
    end

    def on_create
      add_reg :test16, 0x0012, 16, bus: { pos: 8, bits: 8 },
                                   bit: { pos: 0 }

      add_reg :test32, 0x0014, 32, bus: { pos: 16, bits: 16 },
                                   bit: { pos: 0 }

      $tester.set_timeset('nvmbist', 40)
      add_pin :tclk
      add_pin :tdi
      add_pin :tdo
      add_pin :tms
    end
  end
end
