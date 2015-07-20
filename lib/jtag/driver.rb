module JTAG
  # This driver provides methods to read and write from a JTAG instruction
  # and data registers.
  #
  # Low level methods are also provided for fine control of the TAP Controller
  # state machine via the TAPController module.
  #
  # To use this driver the parent model must define the following pins (an alias is fine):
  #   :tclk
  #   :tdi
  #   :tdo
  #   :tms
  class Driver
    REQUIRED_PINS = [:tclk, :tdi, :tdo, :tms]

    include TAPController
    include Origen::Registers

    # Returns the object that instantiated the JTAG
    attr_reader :owner

    # Returns the current value in the instruction register
    attr_reader :ir_value

    attr_accessor :tclk_format
    # Set true to print out debug comments about all state transitions
    attr_accessor :verbose
    alias_method :verbose?, :verbose

    def initialize(owner, options = {})
      @owner = owner
      validate_pins

      # The parent can configure JTAG settings by defining this constant
      if defined?(owner.class::JTAG_CONFIG)
        options = owner.class::JTAG_CONFIG.merge(options)
      end

      # Fallback defaults
      options = {
        verbose:         false,
        tclk_format:     :rh,                  # format of JTAG clock used:  ReturnHigh (:rh), ReturnLo (:rl)
        tclk_multiple:   1,                  # number of cycles for one clock pulse, assumes 50% duty cycle. Uses tester non-return format to spread TCK across multiple cycles.
        #    e.g. @tclk_multiple = 2, @tclk_format = :rh, means one cycle with Tck low (non-return), one with Tck high (NR)
        #         @tclk_multiple = 4, @tclk_format = :rl, means 2 cycles with Tck high (NR), 2 with Tck low (NR)
        tdo_strobe:      :tclk_high,            # when using multiple cycles for TCK, when to strobe for TDO, options include:
        #     :tclk_high   - strobe TDO only when TCK is high
        #     :tclk_low    - strobe TDO only when TCK is low
        #     :tclk_all    - strobe TDO throughout TCK cycle
        tdo_store_cycle: 0,                # store vector cycle within TCK (i.e. when to indicate to tester to store vector within TCK cycle.  0 is first vector, 1 is second, etc.)
        # NOTE: only when user indicates to store TDO, which will mean we don't care the 1 or 0 value on TDO (overriding effectively :tdo_strobe option above)
        init_state:      :unknown
      }.merge(options)

      init_tap_controller(options)

      @verbose = options[:verbose]
      @ir_value = :unknown
      @tclk_format = options[:tclk_format]
      @tclk_multiple = options[:tclk_multiple]
      @tdo_strobe = options[:tdo_strobe]
      @tdo_store_cycle = options[:tdo_store_cycle]
      @state = options[:init_state]
    end

    # Shift data into the TDI pin or out of the TDO pin.
    #
    # There is no TAP controller state checking or handling here, it just
    # shifts some data directly into the pattern, so it is assumed that some
    # higher level logic is co-ordinating the TAP Controller.
    #
    # Most applications should not call this method directly and should instead
    # use the pre-packaged read/write_dr/ir methods.
    # However it is provided as a public API for the corner cases like generating
    # an overlay subroutine pattern where it would be necessary to generate some JTAG
    # vectors outwith the normal state controller wrapper.
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] :size The number of bits to shift. This is optional
    #   when supplying a register or bit collection in which case the size will be derived from
    #   the number of bits supplied. If this option is supplied then it will override
    #   the size derived from the bits. If the size is greater than the number of bits
    #   provided then the additional space will be padded by 0s or don't cares as appropriate.
    # @option options [Boolean] :read (false) When true the given value will be compared on the TDO pin
    #   instead of being shifted into the TDI pin. In the case of a register object being provided
    #   only those bits that are actually marked for read will be compared.
    # @option options [Boolean] :cycle_last (false) Normally the last data bit is applied to the
    #   pins but not cycled, this is to integrate with the TAPController which usually
    #   requires that the TMS value is also changed on the last data bit. To override this
    #   default behavior and force a cycle for the last data bit set this to true.
    # @option options [Boolean] :includes_last_bit (true) When true the TMS pin will be driven
    #   to 1 on the last cycle of the shift if :cycle_last has been specified. To override this
    #   and keep TMS low on the last cycle set this to false. One reason for doing this would be
    #   if generating some subroutine vectors which only represented a partial section of a shift
    #   operation.
    def shift(reg_or_val, options = {})
      options = {
        read:              false,
        cycle_last:        false,
        includes_last_bit: true
      }.merge(options)
      size = extract_size(reg_or_val, options)
      if options.key?(:arm_debug_comment)
        cc options[:arm_debug_comment]
      end
      if options.key?(:arm_debug_overlay)
        $tester.label(options[:arm_debug_overlay])
      end
      size = extract_size(reg_or_val, options)
      contains_bits = (contains_bits?(reg_or_val) || is_a_bit?(reg_or_val))
      owner.pin(:tdi).drive(0) # Drive state when reading out
      owner.pin(:tms).drive(0)
      size.times do |i|
        call_subroutine = false
        if options[:read]
          # If it's a register support bit-wise reads
          if contains_bits
            if reg_or_val[i]
              if reg_or_val[i].is_to_be_stored?
                Origen.tester.store_next_cycle(owner.pin(:tdo))
                owner.pin(:tdo).dont_care if Origen.tester.j750?
              elsif reg_or_val[i].has_overlay?
                if Origen.mode.simulation?
                  owner.pin(:tdo).dont_care
                else
                  call_subroutine = reg_or_val[i].overlay_str
                end
              elsif reg_or_val[i].is_to_be_read?
                owner.pin(:tdo).assert(reg_or_val[i] ? reg_or_val[i] : 0)
              elsif options.key?(:compare_data)
                if i.eql?(0) || i.eql?(1) || i.eql?(2)
                  # Skip comparing first three status bits
                  owner.pin(:tdo).dont_care
                else
                  owner.pin(:tdo).assert(reg_or_val[i] ? reg_or_val[i] : 0)
                end
              else
                owner.pin(:tdo).dont_care
              end
            # If the read width extends beyond the register boundary, don't care
            # the extra bits
            else
              owner.pin(:tdo).dont_care
            end
          # Otherwise read the whole thing
          else
            owner.pin(:tdo).assert(reg_or_val[i] ? reg_or_val[i] : 0)
          end
        else
          if contains_bits && reg_or_val[i] && reg_or_val[i].has_overlay?
            if Origen.mode.simulation?
              owner.pin(:tdi).drive(reg_or_val[i] ? reg_or_val[i] : 0)
            else
              call_subroutine = reg_or_val[i].overlay_str
            end
          elsif options.key?(:arm_debug_overlay)
            if Origen.mode.simulation?
              owner.pin(:tdi).drive(reg_or_val[i] ? reg_or_val[i] : 0)
            else
              $tester.label('// JTAG DATA Pin: ' + i.to_s)
              owner.pin(:tdi).drive(reg_or_val[i] ? reg_or_val[i] : 0)
            end
          else
            owner.pin(:tdi).drive(reg_or_val[i] ? reg_or_val[i] : 0)
          end
        end
        if call_subroutine
          Origen.tester.call_subroutine(call_subroutine)
          @last_data_vector_shifted = true
        else
          @last_data_vector_shifted = false
          # Don't latch the last bit, that will be done when
          # leaving the state.
          if i != size - 1 || options[:cycle_last]
            if i == size - 1 && options[:includes_last_bit]
              owner.pin(:tms).drive(1)
            end
            tclk_cycle do
              Origen.tester.cycle
            end
            owner.pin(:tdo).dont_care
          else
            @deferred_compare = true
          end
        end
      end
      # Clear read and similar flags to reflect that the request has just
      # been fulfilled
      reg_or_val.clear_flags if reg_or_val.respond_to?(:clear_flags)
    end

    # Cycles the tester through one TCLK cycle
    # Adjusts for the TCLK format and cycle span
    # Assumes caller will drive pattern to tester
    # via .drive or similar
    def tclk_cycle
      case @tclk_format
        when :rh
          tclk_val = 0
        when :rl
          tclk_val = 1
        else
          fail 'ERROR: Invalid Tclk timing format!'
      end

      # determine whether to mask TDO on first half cycle
      mask_tdo_half0 =  ((@tclk_format == :rl) && (@tdo_strobe == :tclk_low) && (@tclk_multiple > 1)) ||
                        ((@tclk_format == :rh) && (@tdo_strobe == :tclk_high) && (@tclk_multiple > 1))

      # determine whether to mask TDO on second half cycle
      mask_tdo_half1 =  ((@tclk_format == :rl) && (@tdo_strobe == :tclk_high) && (@tclk_multiple > 1)) ||
                        ((@tclk_format == :rh) && (@tdo_strobe == :tclk_low) && (@tclk_multiple > 1))

      # determine whether TDO is set to capture for this TCK cycle
      tdo_to_be_captured = owner.pin(:tdo).to_be_captured?

      # If TDO is already suspended (by an application) then don't do the
      # suspends below since the resume will clear the application's suspend
      tdo_already_suspended = owner.pin(:tdo).suspended? && !@tdo_suspended_by_driver

      @tclk_multiple.times do |i|
        # 50% duty cycle if @tclk_multiple is even, otherwise slightly off

        if tdo_to_be_captured
          owner.pin(:tdo).state = @tdo_store_cycle == i ? :capture : :dont_care
        end

        if i < (@tclk_multiple + 1) / 2
          # first half of cycle
          owner.pin(:tclk).drive(tclk_val)
          unless tdo_already_suspended
            unless tdo_to_be_captured
              if mask_tdo_half0
                @tdo_suspended_by_driver = true
                owner.pin(:tdo).suspend
              else
                @tdo_suspended_by_driver = false
                owner.pin(:tdo).resume
              end
            end
          end
        else
          # second half of cycle
          owner.pin(:tclk).drive(1 - tclk_val)
          unless tdo_already_suspended
            unless tdo_to_be_captured
              if mask_tdo_half1
                @tdo_suspended_by_driver = true
                owner.pin(:tdo).suspend
              else
                @tdo_suspended_by_driver = false
                owner.pin(:tdo).resume
              end
            end
          end
        end
        yield
      end
      if @tdo_suspended_by_driver
        owner.pin(:tdo).resume
        @tdo_suspended_by_driver = false
      end
    end

    # Applies the given value to the TMS pin and then
    # cycles the tester for one TCLK
    #
    # @param [Integer] val Value to drive on the TMS pin, 0 or 1
    def tms!(val)
      if @deferred_compare
        @deferred_compare = nil
      else
        owner.pin(:tdo).dont_care
      end

      tclk_cycle do
        owner.pin(:tms).drive!(val)
      end
    end

    # Write the given value, register or bit collection to the data register.
    # This is a self contained method that will take care of the TAP controller
    # state transitions, exiting with the TAP controller in Run-Test/Idle.
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be written. If a reg/bit collection is supplied this can be pre-marked for overlay.
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] :size The number of bits to write. This is optional
    #   when supplying a register or bit collection in which case the size will be derived from
    #   the number of bits supplied. If this option is supplied then it will override
    #   the size derived from the bits. If the size is greater than the number of bits
    #   provided then the additional space will be padded by 0s.
    # @option options [String] :msg  By default will not make any comments directly here.  Can pass
    #   a msg to be written out prior to shifting data.
    def write_dr(reg_or_val, options = {})
      if Origen.tester.respond_to?(:write_dr)
        Origen.tester.write_dr(reg_or_val, options)
      else
        if options[:msg]
          cc "#{options[:msg]}\n"
        end
        shift_dr do
          if options[:overlay] == true
            $tester.label(options[:overlay_label], true) # apply global label
          end
          shift(reg_or_val, options)
        end
      end
    end

    # Read the given value, register or bit collection from the data register.
    # This is a self contained method that will take care of the TAP controller
    # state transitions, exiting with the TAP controller in Run-Test/Idle.
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be read. If a reg/bit collection is supplied this can be pre-marked for read in which
    #   case only the marked bits will be read and the vectors corresponding to the data from the non-read
    #   bits will be set to don't care. Similarly the bits can be pre-marked for store (capture) or
    #   overlay.
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] :size The number of bits to read. This is optional
    #   when supplying a register or bit collection in which case the size will be derived from
    #   the number of bits supplied. If the size is supplied then it will override
    #   the size derived from the bits. If the size is greater than the number of bits
    #   provided then the additional space will be padded by don't care cycles.
    # @option options [String] :msg  By default will not make any comments directly here.  Can pass
    #   a msg to be written out prior to shifting data.
    def read_dr(reg_or_val, options = {})
      if Origen.tester.respond_to?(:read_dr)
        Origen.tester.read_dr(reg_or_val, options)
      else
        options = {
          read: true
        }.merge(options)
        if options[:msg]
          cc "#{options[:msg]}\n"
        end
        shift_dr do
          if options[:overlay] == true
            $tester.label(options[:overlay_label], true) # apply global label
          end
          shift(reg_or_val, options)
        end
      end
    end

    # Write the given value, register or bit collection to the instruction register.
    # This is a self contained method that will take care of the TAP controller
    # state transitions, exiting with the TAP controller in Run-Test/Idle.
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be written. If a reg/bit collection is supplied this can be pre-marked for overlay.
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] :size The number of bits to write. This is optional
    #   when supplying a register or bit collection in which case the size will be derived from
    #   the number of bits supplied. If this option is supplied then it will override
    #   the size derived from the bits. If the size is greater than the number of bits
    #   provided then the additional space will be padded by 0s.
    # @option options [Boolean] :force By default multiple calls to this method will not generate
    #   multiple writes. This is to allow wrapper algorithms to remain efficient yet not have to
    #   manually track the IR state (and in many cases this may be impossible due to multiple
    #   protocols using the same JTAG). To force a write regardless of what the driver thinks the IR
    #   contains set this to true.
    # @option options [String] :msg  By default will not make any comments directly here.  Can pass
    #   a msg to be written out prior to shifting in IR data.  Will not write comment only if write
    #   occurs.
    def write_ir(reg_or_val, options = {})
      if Origen.tester.respond_to?(:write_ir)
        Origen.tester.write_ir(reg_or_val, options)
      else
        val = reg_or_val.respond_to?(:data) ? reg_or_val.data : reg_or_val
        if val != ir_value || options[:force]
          if options[:msg]
            cc "#{options[:msg]}\n"
          end
          shift_ir do
            shift(reg_or_val, options)
          end
          @ir_value = val
        end
      end
    end

    # Read the given value, register or bit collection from the instruction register.
    # This is a self contained method that will take care of the TAP controller
    # state transitions, exiting with the TAP controller in Run-Test/Idle.
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be read. If a reg/bit collection is supplied this can be pre-marked for read in which
    #   case only the marked bits will be read and the vectors corresponding to the data from the non-read
    #   bits will be set to don't care. Similarly the bits can be pre-marked for store (capture) or
    #   overlay.
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] :size The number of bits to read. This is optional
    #   when supplying a register or bit collection in which case the size will be derived from
    #   the number of bits supplied. If the size is supplied then it will override
    #   the size derived from the bits. If the size is greater than the number of bits
    #   provided then the additional space will be padded by don't care cycles.
    # @option options [String] :msg  By default will not make any comments directly here.  Can pass
    #   a msg to be written out prior to shifting data.
    def read_ir(reg_or_val, options = {})
      if Origen.tester.respond_to?(:read_ir)
        Origen.tester.read_ir(reg_or_val, options)
      else
        options = {
          read: true
        }.merge(options)
        if options[:msg]
          cc "#{options[:msg]}\n"
        end
        shift_ir do
          shift(reg_or_val, options)
        end
      end
    end

    private

    def extract_size(reg_or_val, options = {})
      size = options[:size]
      unless size
        if reg_or_val.is_a?(Fixnum) || !reg_or_val.respond_to?(:size)
          fail 'When suppling a value to JTAG::Driver#shift you must supply a :size in the options!'
        else
          size = reg_or_val.size
        end
      end
      size
    end

    # Validates that the parent object (the owner) has defined the necessary
    # pins to implement the JTAG
    def validate_pins
      REQUIRED_PINS.each do |name|
        owner.pin(name)
      end
    rescue
      puts 'Missing JTAG pins!'
      puts "In order to use the JTAG driver your #{owner.class} class must define"
      puts 'the following pins (an alias is fine):'
      puts REQUIRED_PINS
      raise 'JTAG driver error!'
    end
  end
end
