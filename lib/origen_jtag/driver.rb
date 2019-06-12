module OrigenJTAG
  # This driver provides methods to read and write from a JTAG instruction
  # and data registers.
  #
  # Low level methods are also provided for fine control of the TAP Controller
  # state machine via the TAPController module.
  #
  # To use this driver the parent model must define the following pins (an alias is fine):
  #   :tck
  #   :tdi
  #   :tdo
  #   :tms
  class Driver
    REQUIRED_PINS = [:tck, :tdi, :tdo, :tms]

    include Origen::Model
    include TAPController
    # include Origen::Registers

    # Returns the object that instantiated the JTAG
    attr_reader :owner

    # Returns the current value in the instruction register
    attr_reader :ir_value

    # The number of cycles for one clock pulse, assumes 50% duty cycle. Uses tester non-return format to spread TCK across multiple cycles.
    #    e.g. @tck_multiple = 2, @tck_format = :rh, means one cycle with Tck low (non-return), one with Tck high (NR)
    #         @tck_multiple = 4, @tck_format = :rl, means 2 cycles with Tck high (NR), 2 with Tck low (NR)
    attr_accessor :tck_multiple
    alias_method :tclk_multiple, :tck_multiple
    alias_method :tclk_multiple=, :tck_multiple=

    # Wave/timing format of the JTAG clock:  :rh (ReturnHigh) or :rl (ReturnLo), :rh is the default
    attr_accessor :tck_format
    alias_method :tclk_format, :tck_format
    alias_method :tclk_format=, :tck_format=

    attr_accessor :tdo_strobe
    attr_accessor :tdo_store_cycle

    # Set true to print out debug comments about all state transitions
    attr_accessor :verbose
    alias_method :verbose?, :verbose

    # Log all state changes in pattern comments, false by default
    attr_accessor :log_state_changes

    def initialize(owner, options = {})
      if owner.is_a?(Hash)
        @owner = parent
        options = owner
      else
        @owner = owner
      end
      # The parent can configure JTAG settings by defining this constant
      if defined?(owner.class::JTAG_CONFIG)
        options = owner.class::JTAG_CONFIG.merge(options)
      end

      @cycle_callback = options[:cycle_callback]
      @given_options = options.dup  # Save these for later use in the pins method

      # Fallback defaults
      options = {
        verbose:         false,
        tdo_store_cycle: 0,                # store vector cycle within TCK (i.e. when to indicate to tester to store vector within TCK cycle.  0 is first vector, 1 is second, etc.)
        # NOTE: only when user indicates to store TDO, which will mean we don't care the 1 or 0 value on TDO (overriding effectively :tdo_strobe option above)
        init_state:      :unknown
      }.merge(options)

      init_tap_controller(options)

      @verbose = options[:verbose]
      @ir_value = :unknown
      @tck_format = options[:tck_format] || options[:tclk_format] || :rh
      @tck_multiple = options[:tck_multiple] || options[:tclk_multiple] || 1
      self.tdo_strobe = options[:tdo_strobe] || :tck_high
      @tdo_store_cycle = options[:tdo_store_cycle]
      @state = options[:init_state]
      @log_state_changes = options[:log_state_changes] || false
      if options[:tck_vals] || options[:tclk_vals]
        @tck_vals = options[:tck_vals] || options[:tclk_vals]
        unless @tck_vals.is_a?(Hash) && @tck_vals.key?(:on) && @tck_vals.key?(:off)
          fail "When specifying TCK values, you must supply a hash with both :on and :off keys, e.g. tck_vals: { on: 'P', off: 0 }"
        end
      end
      if @cycle_callback && @tck_multiple != 1
        fail 'A cycle_callback can only be used with a tck_multiple setting of 1'
      end
    end

    # when using multiple cycles for TCK, set when to strobe for TDO, options include:
    #     :tck_high   - strobe TDO only when TCK is high (Default)
    #     :tck_low    - strobe TDO only when TCK is low
    #     :tck_all    - strobe TDO throughout TCK cycle
    def tdo_strobe=(val)
      case val
      when :tck_high, :tclk_high
        @tdo_strobe = :tck_high
      when :tck_low, :tclk_low
        @tdo_strobe = :tck_low
      when :tck_all, :tclk_all
        @tdo_strobe = :tck_all
      else
        fail 'tdo_strobe must be set to one of: :tck_high, :tck_low or :tck_all'
      end
    end

    # When true it means that the application is dealing with how to handle the 4 JTAG signals for each JTAG cycle.
    # In that case this driver calculates what state the 4 pins should be in each signal and then calls back to the
    # application with that information and it is up to the application to decide what to do with that information
    # and when/if to generate tester cycles.
    def cycle_callback?
      !!@cycle_callback
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
        includes_last_bit: true,
        no_subr:           false      # do not use subroutine for any overlay
      }.merge(options)

      # save compression state for restoring afterwards
      compression_on = !Origen.tester.dont_compress

      # clean incoming data
      size = extract_size(reg_or_val, options)
      tdi_reg = extract_shift_in_data(reg_or_val, size, options)
      tdo_reg = extract_shift_out_data(reg_or_val, size, options)
      global_ovl, ovl_reg = extract_overlay_data(reg_or_val, size, options)

      # let the tester handle overlay if possible
      unless tester.respond_to?(:source_memory)
        # tester does not support direct labels, so can't do
        if options[:no_subr] && !$tester.respond_to?('label')
          cc 'This tester does not support use of labels, cannot do no_subr option as requested'
          cc '  going with subroutine overlay instead'
          options[:no_subr] = false
        end

        # insert global label if specified
        if global_ovl
          if $tester.respond_to?('label')
            $tester.label(global_ovl, true)
          else
            cc "Unsupported global label: #{global_ovl}"
          end
        end
      end # of let tester handle overlay if possible

      # loop through each data bit
      last_overlay_label = ''
      size.times do |i|
        store_tdo_this_tck = false

        # Set up pin actions for bit transaction (tck cycle)

        # TDI
        action :tdi, :drive, tdi_reg[i]

        # TDO
        action :tdo, :dont_care                                 # default setting
        if tdo_reg[i]
          if tdo_reg[i].is_to_be_stored?                        # store
            store_tdo_this_tck = true
            action :tdo, :dont_care if Origen.tester.j750?
          elsif tdo_reg[i].is_to_be_read?                       # compare/assert
            action :tdo, :assert, tdo_reg[i], meta: { position: i }
          end
        end

        # TMS
        action :tms, :drive, 0

        # let tester handle overlay if implemented
        overlay_options = {}
        if tester.respond_to?(:source_memory) && !cycle_callback?
          if ovl_reg[i] && ovl_reg[i].has_overlay? && !Origen.mode.simulation?
            overlay_options[:pins] = pins[:tdi]
            if global_ovl
              overlay_options[:overlay_str] = global_ovl
            else
              overlay_options[:overlay_str] = ovl_reg[i].overlay_str
            end
            if options[:no_subr] || global_ovl
              if global_ovl
                overlay_options[:overlay_style] = :global_label
              else
                overlay_options[:overlay_style] = :label
              end
            end
            tester_subr_overlay = !(options[:no_subr] || global_ovl) && tester.overlay_style == :subroutine
            action :tdi, :drive, 0 if tester_subr_overlay
            action :tdo, :assert, tdo_reg[i], meta: { position: i } if options[:read] unless tester_subr_overlay
            # Force the last bit to be shifted from this method if overlay requested on the last bit
            options[:cycle_last] = true if i == size - 1
          end
        else
          # Overlay - reconfigure pin action for overlay if necessary
          if ovl_reg[i] && ovl_reg[i].has_overlay? && !Origen.mode.simulation?
            if options[:no_subr]
              Origen.tester.dont_compress = true
              if ovl_reg[i].overlay_str != last_overlay_label
                $tester.label(ovl_reg[i].overlay_str)
                last_overlay_label = ovl_reg[i].overlay_str
              end
              action :tdo, :assert, tdo_reg[i], meta: { position: i } if options[:read]
            else
              action :tdi, :drive, 0
              call_subroutine = ovl_reg[i].overlay_str
            end
          end
        end # of let tester handle overlay

        # With JTAG pin actions queued up, use block call to tck_cycle to
        #   execute a single TCK period.  Special handling of subroutines,
        #   case of last bit in shift, and store vector (within a multi-cycle
        #   tck config).
        if call_subroutine || tester_subr_overlay
          @last_data_vector_shifted = true
        else
          @last_data_vector_shifted = false
        end

        if call_subroutine
          Origen.tester.call_subroutine(call_subroutine)
        else
          @next_data_vector_to_be_stored = false
          # Don't latch the last bit, that will be done when leaving the state.
          if i != size - 1 || options[:cycle_last]
            if i == size - 1 && options[:includes_last_bit]
              unless tester_subr_overlay
                action :tms, :drive, 1
                @last_data_vector_shifted = true
              end
            end
            tck_cycle do
              if store_tdo_this_tck && @next_data_vector_to_be_stored
                action :store
              end
              if overlay_options[:pins].nil? || cycle_callback?
                cycle
              else
                cycle overlay: overlay_options
                overlay_options[:change_data] = false			# data change only on first cycle if overlay
              end
            end
            pins[:tdo].dont_care unless cycle_callback?
          else
            @deferred_compare = true
            @deferred_store = true if store_tdo_this_tck
          end
        end
      end

      # Clear read and similar flags to reflect that the request has just been fulfilled
      reg_or_val.clear_flags if reg_or_val.respond_to?(:clear_flags)

      # put back compression if turned on above
      Origen.tester.dont_compress = false if compression_on
    end

    # Cycles the tester through one TCK cycle
    # Adjusts for the TCK format and cycle span
    # Assumes caller will drive pattern to tester
    # via .drive or similar
    def tck_cycle
      if cycle_callback?
        @next_data_vector_to_be_stored = @tdo_store_cycle
        yield
      else
        case @tck_format
          when :rh
            tck_val = 0
          when :rl
            tck_val = 1
          else
            fail 'ERROR: Invalid Tclk timing format!'
        end

        # determine whether to mask TDO on first half cycle
        mask_tdo_half0 =  ((@tck_format == :rl) && (@tdo_strobe == :tck_low) && (@tck_multiple > 1)) ||
                          ((@tck_format == :rh) && (@tdo_strobe == :tck_high) && (@tck_multiple > 1))

        # determine whether to mask TDO on second half cycle
        mask_tdo_half1 =  ((@tck_format == :rl) && (@tdo_strobe == :tck_high) && (@tck_multiple > 1)) ||
                          ((@tck_format == :rh) && (@tdo_strobe == :tck_low) && (@tck_multiple > 1))

        # If TDO is already suspended (by an application) then don't do the
        # suspends below since the resume will clear the application's suspend
        tdo_already_suspended = !cycle_callback? && pins[:tdo].suspended? && !@tdo_suspended_by_driver

        @tck_multiple.times do |i|
          # 50% duty cycle if @tck_multiple is even, otherwise slightly off

          @next_data_vector_to_be_stored = @tdo_store_cycle == i ? true : false

          if i < (@tck_multiple + 1) / 2
            # first half of cycle
            pins[:tck].drive(@tck_vals ? @tck_vals[:on] : tck_val)
            unless tdo_already_suspended
              if mask_tdo_half0
                @tdo_suspended_by_driver = true
                pins[:tdo].suspend
              else
                @tdo_suspended_by_driver = false
                pins[:tdo].resume
              end
            end
          else
            # second half of cycle
            pins[:tck].drive(@tck_vals ? @tck_vals[:off] : (1 - tck_val))
            unless tdo_already_suspended
              if mask_tdo_half1
                @tdo_suspended_by_driver = true
                pins[:tdo].suspend
              else
                @tdo_suspended_by_driver = false
                pins[:tdo].resume
              end
            end
          end
          yield
        end
        if @tdo_suspended_by_driver
          @tdo_suspended_by_driver = false
          pins[:tdo].resume
        end
      end
    end
    alias_method :tclk_cycle, :tck_cycle

    # Applies the given value to the TMS pin and then
    # cycles the tester for one TCK
    #
    # @param [Integer] val Value to drive on the TMS pin, 0 or 1
    def tms!(val)
      if @deferred_compare
        @deferred_compare = nil
      else
        action :tdo, :dont_care
      end

      if @deferred_store
        @deferred_store = nil
        store_tdo_this_tck = true
      else
        store_tdo_this_tck = false
      end
      @next_data_vector_to_be_stored = false

      tck_cycle do
        if store_tdo_this_tck && @next_data_vector_to_be_stored
          action :store
        end
        action :tms, :drive, val
        cycle
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
        val = reg_or_val.respond_to?(:data) ? reg_or_val.data : reg_or_val
        shift_dr(write: val.to_hex) do
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
        shift_dr(read: Origen::Utility.read_hex(reg_or_val)) do
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
          shift_ir(write: val.to_hex) do
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
        shift_ir(read: Origen::Utility.read_hex(reg_or_val)) do
          shift(reg_or_val, options)
        end
      end
    end

    def apply_action(pin, actions)
      actions.each do |operation|
        method = operation.shift
        pin.send(method, *operation) if method
      end
    end

    private

    def action(pin_id, *operations)
      @actions ||= clear_actions
      if pin_id == :store
        @actions[:store] = true
      else
        fail "Unkown JTAG pin ID: #{pin_id}" unless @actions[pin_id]
        @actions[pin_id] << operations
      end
    end

    def cycle(options = {})
      if @actions
        if cycle_callback?
          @owner.send(@cycle_callback, @actions, options)
        else
          apply_action(pins[:tms], @actions[:tms])
          apply_action(pins[:tdi], @actions[:tdi])
          apply_action(pins[:tdo], @actions[:tdo])
          tester.store_next_cycle(pins[:tdo]) if @actions[:store]
          tester.cycle(options)
        end
        clear_actions
      end
    end

    def clear_actions
      @actions = { tdi: [], tms: [], tdo: [], store: false }
    end

    # Return size of transaction.  Options[:size] has priority and need not match the
    #   register size.  Any mismatch will be handled by the api.
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

    # Combine any legacy options into a single global overlay and create
    #   new bit collection to track any bit-wise overlays.
    def extract_overlay_data(reg_or_val, size, options = {})
      if reg_or_val.respond_to?(:data)
        ovl = reg_or_val.dup
      else
        ovl = Reg.dummy(size)
      end

      if options[:overlay]
        global = options[:overlay_label]
      elsif options.key?(:arm_debug_overlay)   # prob don't need this anymore
        global = options[:arm_debug_overlay]   # prob don't need this anymore
      else
        global = nil
      end

      [global, ovl]
    end

    # Create data that will be shifted in on TDI, create new bit collection
    #   on the fly if reg_or_val arg is data only.  Consider read operation
    #   where caller has requested (specific) shift in data to be used.
    def extract_shift_in_data(reg_or_val, size, options = {})
      if reg_or_val.respond_to?(:data)
        if options[:read]
          data = options[:shift_in_data] || 0
          tdi = Reg.dummy(size)
          tdi.write(data)
        else
          tdi = reg_or_val.dup
        end
      else
        # Not a register model, so can't support bit-wise overlay
        tdi = Reg.dummy(size)
        if options[:read]
          data = options[:shift_in_data] || 0
          tdi.write(data)
        else
          tdi.write(reg_or_val)
        end
      end
      tdi
    end

    # Create data that will be shifted out on TDO, create new bit collection
    #   on the fly if reg_or_val arg is data only.  Consider write operation
    #   where caller has requested (specific) shift out data to be compared.
    def extract_shift_out_data(reg_or_val, size, options = {})
      if reg_or_val.respond_to?(:data)
        if options[:read]
          tdo = reg_or_val.dup
          tdo.read(options) unless options[:mask].nil?
        else
          tdo = Reg.dummy(size) unless options[:shift_out_data].is_a?(Origen::Registers::Reg)
        end
        unless options[:read]			# if this is a write operation
          if options[:shift_out_data]
            if options[:shift_out_data].class.to_s =~ /Origen::Registers/
              tdo = options[:shift_out_data]
            else
              tdo.write(options[:shift_out_data])
              tdo.read(options)
            end
          else
            tdo.write(0)
          end
        end
      else
        tdo = Reg.dummy(size)
        if options[:read]
          tdo.write(reg_or_val)
          tdo.read(options)
        else
          if options[:shift_out_data]
            if options[:shift_out_data].class.to_s =~ /Origen::Registers/
              tdo = options[:shift_out_data]
            else
              tdo.write(options[:shift_out_data])
              tdo.read(options)
            end
          else
            tdo.write(0)
          end
        end
      end
      tdo
    end

    def to_pin(pin_or_id)
      if pin_or_id
        if pin_or_id.is_a?(Symbol) || pin_or_id.is_a?(String)
          @owner.pin(pin_or_id)
        else
          pin_or_id
        end
      end
    end

    def pins
      @pins ||= begin
        pins = {}
        pins[:tck] = to_pin(@given_options[:tck_pin])
        pins[:tdi] = to_pin(@given_options[:tdi_pin])
        pins[:tdo] = to_pin(@given_options[:tdo_pin])
        pins[:tms] = to_pin(@given_options[:tms_pin])

        # Support legacy implementation where tck was incorrectly called tclk, in case of both being
        # defined then :tck has priority
        pins[:tck] ||= @owner.pin(:tck) if @owner.has_pin?(:tck)
        pins[:tck] ||= @owner.pin(:tclk)
        pins[:tdi] ||= @owner.pin(:tdi)
        pins[:tdo] ||= @owner.pin(:tdo)
        pins[:tms] ||= @owner.pin(:tms)

        pins
      end
    rescue
      puts 'Missing JTAG pins!'
      puts "In order to use the JTAG driver your #{owner.class} class must either define"
      puts 'the following pins (an alias is fine):'
      puts REQUIRED_PINS
      puts '-- or --'
      puts 'Pass the pin IDs to be used instead in the initialization options:'
      puts "sub_block :jtag, class_name: 'OrigenJTAG::Driver', tck_pin: :clk, tdi_pin: :gpio1, tdo_pin: :gpio2, tms_pin: :gpio3"
      raise 'JTAG driver error!'
    end
  end
end
