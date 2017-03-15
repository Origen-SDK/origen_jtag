module OrigenJTAGDev
  # This is a dummy DUT model which is used
  # to instantiate and test the JTAG locally
  # during development.
  #
  # It is not included when this library is imported.
  class DUT
    include Origen::TopLevel
    include OrigenJTAG

    attr_reader :jtag_config

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

      instantiate_registers(options)
      instantiate_pins(options)

      tester.set_timeset('nvmbist', 40)
    end

    def instantiate_registers(options = {})
      reg :test16, 0x0012, size: 16 do |reg|
        reg.bit 15..8, :bus
        reg.bit 0, :bit
      end

      reg :test32, 0x0014, size: 32 do |reg|
        reg.bit 31..16, :bus
        reg.bit 0, :bit
      end
    end

    def instantiate_pins(options = {})
      add_pin :tclk
      add_pin :tdi
      add_pin :tdo
      add_pin :tms
    end

    # Getter for top-level tclk_format setting
    def tclk_format
      JTAG_CONFIG[:tclk_format]
    end

    # Getter for top-level tclk_multiple setting
    def tclk_multiple
      JTAG_CONFIG[:tclk_multiple]
    end

    # Getter for top-level tdo_strobe setting
    def tdo_strobe
      JTAG_CONFIG[:tdo_strobe]
    end

    # Getter for top-level tdo_store_cycle setting
    def tdo_store_cycle
      JTAG_CONFIG[:tdo_store_cycle]
    end

    # Getter for top-level init_state setting
    def init_state
      JTAG_CONFIG[:init_state]
    end

    # Wouldn't want to do this in reality, but allows some flexibility duing gem testing
    def update_jtag_config(cfg, val)
      if JTAG_CONFIG.key?(cfg)
        JTAG_CONFIG[cfg] = val
      else
        fail "#{cfg} not a part of JTAG_CONFIG"
      end
    end
  end
end
