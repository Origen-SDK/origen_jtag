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
    include RGen::Registers

    # Returns the object that instantiated the JTAG
    attr_reader :owner

    # Set true to print out debug comments about all state transitions
    attr_accessor :verbose
    alias :verbose? :verbose

    def initialize(owner, options={})
      @owner = owner
      validate_pins

      # The parent can configure JTAG settings by defining this constant
      if defined?(owner.class::JTAG_CONFIG)
        options = owner.class::JTAG_CONFIG.merge(options)
      end

      # Fallback defaults
      options = {
        :verbose => false,
      }.merge(options)

      init_tap_controller(options)

      @verbose = options[:verbose]
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
    # @param [Integer, RGen::Register::Reg, RGen::Register::BitCollection, RGen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] :size The number of bits to shift. This is optional
    #   when supplying a register or bit collection in which case the size will be derived from
    #   the number of bits supplied. If this option is supplied then it will override
    #   the size derived from the bits. If the size is greater than the number of bits
    #   provided then the additional space will be padded by 0s or don't cares as appropriate.
    # @option options [Boolean] :read When true the given value will be compared on the TDO pin
    #   instead of being shifted into the TDI pin. Read is assumed when the supplied value contains
    #   some bits that have been marked for read.
    # @option options [Boolean] :cycle_last Normally the last data bit is applied to the
    #   pins but not cycled, this is to integrate with the TAPController which usually
    #   requires that the TMS value is also changed on the last data bit. To override this
    #   default behavior and force a cycle for the last data bit set this to true.
    def shift(reg_or_val, options={})
      size = extract_size(reg_or_val, options)
      contains_bits = contains_bits?(reg_or_val)
      owner.pin(:tdi).drive(0) # Drive state when reading out
      size.times do |i|
        call_subroutine = false
        if options[:read] || (contains_bits && reg_or_val.is_to_be_read?)
          # If it's a register support bit-wise reads
          if contains_bits
            if reg_or_val[i]
              if reg_or_val[i].is_to_be_stored?
                RGen.tester.store_next_cycle(owner.pin(:tdo))
                owner.pin(:tdo).dont_care if RGen.tester.j750?
              elsif reg_or_val[i].has_overlay?
                call_subroutine = reg_or_val[i].overlay_str
              elsif reg_or_val[i].is_to_be_read?
                owner.pin(:tdo).assert(reg_or_val[i])
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
            owner.pin(:tdo).assert(reg_or_val[i])
          end
        else
          if contains_bits && reg_or_val[i] && reg_or_val[i].has_overlay?
            call_subroutine = reg_or_val[i].overlay_str
          else
            owner.pin(:tdi).drive(reg_or_val[i])
          end
        end
        if call_subroutine
          RGen.tester.call_subroutine(call_subroutine)
        else
          # Don't latch the last bit, that will be done when
          # leaving the state.
          if i != size - 1 || options[:cycle_last]
            RGen.tester.cycle
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
      owner.pin(:tclk).drive(0)  # Do we need to provide a pos/neg clk option?
      owner.pin(:tms).drive!(val)
    end

    # Write the given value, register or bit collection to the data register.
    # This is a self contained method that will take care of the TAP controller
    # state transitions, exiting with the TAP controller in Run-Test/Idle.
    #
    # @param [Integer, RGen::Register::Reg, RGen::Register::BitCollection, RGen::Register::Bit] reg_or_val
    #   Value to be written. If a reg/bit collection is supplied this can be pre-marked for overlay.
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] :size The number of bits to write. This is optional
    #   when supplying a register or bit collection in which case the size will be derived from
    #   the number of bits supplied. If this option is supplied then it will override
    #   the size derived from the bits. If the size is greater than the number of bits
    #   provided then the additional space will be padded by 0s.
    def write_dr(reg_or_val, options={})
      shift_dr do
        shift(reg_or_val, options)
      end
    end

    # Read the given value, register or bit collection from the data register.
    # This is a self contained method that will take care of the TAP controller
    # state transitions, exiting with the TAP controller in Run-Test/Idle.
    #
    # @param [Integer, RGen::Register::Reg, RGen::Register::BitCollection, RGen::Register::Bit] reg_or_val
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
    def read_dr(reg_or_val, options)
      options = {
        :read => true,
      }.merge(options)
      shift_dr do
        shift(reg_or_val, options)
      end
    end

    # Write the given value, register or bit collection to the instruction register.
    # This is a self contained method that will take care of the TAP controller
    # state transitions, exiting with the TAP controller in Run-Test/Idle.
    #
    # @param [Integer, RGen::Register::Reg, RGen::Register::BitCollection, RGen::Register::Bit] reg_or_val
    #   Value to be written. If a reg/bit collection is supplied this can be pre-marked for overlay.
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] :size The number of bits to write. This is optional
    #   when supplying a register or bit collection in which case the size will be derived from
    #   the number of bits supplied. If this option is supplied then it will override
    #   the size derived from the bits. If the size is greater than the number of bits
    #   provided then the additional space will be padded by 0s.
    def write_ir(reg_or_val, options={})
      shift_ir do
        shift(reg_or_val, options)
      end
    end

    # Read the given value, register or bit collection from the instruction register.
    # This is a self contained method that will take care of the TAP controller
    # state transitions, exiting with the TAP controller in Run-Test/Idle.
    #
    # @param [Integer, RGen::Register::Reg, RGen::Register::BitCollection, RGen::Register::Bit] reg_or_val
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
    def read_ir(reg_or_val, options)
      options = {
        :read => true,
      }.merge(options)
      shift_ir do
        shift(reg_or_val, options)
      end
    end

    private

    def contains_bits?(reg_or_val)
      # RGen should provide a better way of doing this...
      [RGen::Registers::Reg,
       RGen::Registers::BitCollection,
       RGen::Registers::Bit].include?(reg_or_val.class)
    end

    def extract_size(reg_or_val, options={})
      size = options[:size]
      unless size
        if reg_or_val.is_a?(Fixnum) || !reg_or_val.respond_to?(:size)
          raise "When suppling a value to JTAG::Driver#shift you must supply a :size in the options!"
        else
          size = reg_or_val.size
        end
      end
      size
    end

    # Validates that the parent object (the owner) has defined the necessary
    # pins to implement the JTAG
    def validate_pins
      begin
        # Access each pin, if any errors are raised it means the pin is
        # not defined
        REQUIRED_PINS.each do |name|
          owner.pin(name)
        end
      rescue
        puts "Missing JTAG pins!"
        puts "In order to use the JTAG driver your #{owner.class} class must define"
        puts "the following pins (an alias is fine):"
        puts REQUIRED_PINS
        raise "JTAG driver error!"
      end
    end

  end
end
