module OrigenJTAGDev
  # This is a dummy DUT model which is used
  # to instantiate and test the JTAG locally
  # during development.
  #
  # It is not included when this library is imported.
  class Serial
    include Origen::TopLevel

    def initialize(options = {})
      @jtag_config = {
        verbose:         true,
        tclk_format:     options[:tclk_format] || :rh,
        tclk_multiple:   options[:tclk_multiple] || 1,
        tdo_strobe:      options[:tdo_strobe] || :tclk_high,
        tdo_store_cycle: options[:tdo_store_cycle] || 0,
        init_state:      options[:init_state] || :unknown,
        cycle_callback:  :jtag_cycle
      }

      add_pin :tck
      add_pin :tio

      instantiate_registers(options)
      sub_block :jtag, { class_name: 'OrigenJTAG::Driver' }.merge(@jtag_config)
    end

    def jtag_cycle(actions, options = {})
      apply_action(pin(:tio), actions[:tdi])
      tester.cycle(options)
      apply_action(pin(:tio), actions[:tms])
      tester.cycle(options)
      apply_action(pin(:tio), actions[:tdo])
      tester.store_next_cycle(pin(:tio)) if actions[:store]
      tester.cycle(options)
    end

    def apply_action(pin, actions)
      actions.each do |operation|
        method = operation.shift
        pin.send(method, *operation) if method
      end
    end

    def startup(options = {})
      tester.set_timeset('nvmbist', 40)
      pin(:tck).drive(1)
    end

    # Getter for top-level tclk_format setting
    def tclk_format
      @jtag_config[:tclk_format]
    end

    # Getter for top-level tclk_multiple setting
    def tclk_multiple
      @jtag_config[:tclk_multiple]
    end

    # Getter for top-level tdo_store_cycle setting
    def tdo_store_cycle
      @jtag_config[:tdo_store_cycle]
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
  end
end
