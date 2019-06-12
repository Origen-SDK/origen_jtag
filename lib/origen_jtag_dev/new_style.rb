module OrigenJTAGDev
  # This is a dummy DUT model which is used
  # to instantiate and test the JTAG locally
  # during development.
  #
  # It is not included when this library is imported.
  class NewStyle
    include Origen::TopLevel

    attr_reader :jtag_config

    def initialize(options = {})
      @jtag_config = {
        verbose:         true,
        tclk_format:     :rh,
        tclk_multiple:   1,
        tdo_strobe:      :tclk_high,
        tdo_store_cycle: 0,
        init_state:      :unknown
      }
      @jtag_config[:tclk_format] = options[:tclk_format] if options[:tclk_format]
      @jtag_config[:tclk_multiple] = options[:tclk_multiple] if options[:tclk_multiple]
      @jtag_config[:tdo_strobe] = options[:tdo_strobe] if options[:tdo_strobe]
      @jtag_config[:tdo_store_cycle] = options[:tdo_store_cycle] if options[:tdo_store_cycle]
      @jtag_config[:init_state] = options[:init_state] if options[:init_state]
      @jtag_config[:tclk_vals] = options[:tclk_vals] if options[:tclk_vals]
      @jtag_config[:cycle_callback] = options[:cycle_callback] if options[:cycle_callback]

      instantiate_registers(options)
      instantiate_pins(options)
      sub_block :jtag, { class_name: 'OrigenJTAG::Driver' }.merge(@jtag_config)
      if options[:extra_port]
        # Test supplying both pin IDs (recommended) and pin objects (legacy)
        sub_block :jtag2, { class_name: 'OrigenJTAG::Driver', tck_pin: :tck_2, tdi_pin: :tdi_2, tdo_pin: pin(:tdo_2), tms_pin: pin(:tms_2) }.merge(@jtag_config)
      end
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

      reg :full16, 0x0012, size: 16 do |reg|
        reg.bit 15..0, :data
      end
    end

    def instantiate_pins(options = {})
      add_pin :tclk
      unless options[:invalid_pins]
        add_pin :tdi
      end
      add_pin :tdo
      add_pin :tms

      if options[:extra_port]
        add_pin :tck_2
        add_pin :tdi_2
        add_pin :tdo_2
        add_pin :tms_2
      end
    end

    def startup(options = {})
      tester.set_timeset('nvmbist', 40)
    end

    # Getter for top-level tclk_format setting
    def tclk_format
      @jtag_config[:tclk_format]
    end

    # Getter for top-level tclk_multiple setting
    def tclk_multiple
      @jtag_config[:tclk_multiple]
    end

    # Getter for top-level tclk_vals setting
    def tclk_vals
      @jtag_config[:tclk_vals]
    end

    # Getter for top-level tdo_strobe setting
    def tdo_strobe
      @jtag_config[:tdo_strobe]
    end

    # Getter for top-level tdo_store_cycle setting
    def tdo_store_cycle
      @jtag_config[:tdo_store_cycle]
    end

    # Getter for top-level init_state setting
    def init_state
      @jtag_config[:init_state]
    end

    # Wouldn't want to do this in reality, but allows some flexibility during gem testing
    def update_jtag_config(cfg, val)
      if @jtag_config.key?(cfg)
        @jtag_config[cfg] = val
      else
        fail "#{cfg} not a part of @jtag_config"
      end
    end
  end
end
