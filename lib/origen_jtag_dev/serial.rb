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

    def jtag_cycle(actions)
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
