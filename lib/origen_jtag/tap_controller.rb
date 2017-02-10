module OrigenJTAG
  # Provides methods specifically for controlling the state of the
  # TAP Controller
  module TAPController
    # Map of internal state symbols to human readable names
    STATES = {
      reset:      'Test-Logic-Reset',
      idle:       'Run-Test/Idle',
      select_dr:  'Select-DR',
      capture_dr: 'Capture-DR',
      shift_dr:   'Shift-DR',
      exit1_dr:   'Exit1-DR',
      pause_dr:   'Pause-DR',
      exit2_dr:   'Exit2-DR',
      update_dr:  'Update-DR',
      select_ir:  'Select-IR',
      capture_ir: 'Capture-IR',
      shift_ir:   'Shift-IR',
      exit1_ir:   'Exit1-IR',
      pause_ir:   'Pause-IR',
      exit2_ir:   'Exit2-IR',
      update_ir:  'Update-IR'
    }

    # Returns the current state of the JTAG TAP Controller
    attr_reader :state
    alias_method :current_state, :state

    # Goto Shift-DR state then exit back to Run-Test/Idle
    #
    # @example Trandition into Shift-DR
    #   # State is Run-Test/Idle
    #   jtag.shift_dr do
    #     # State is Shift-DR
    #   end
    #   # State is Run-Test/Idle
    #
    # This method can be nested inside of a pause_dr block
    # to transition into the Shift-DR state and then back
    # to Pause-DR
    #
    # @example Switching between Pause-DR and Shift-DR
    #   # State is Run-Test/Idle
    #   jtag.pause_dr do
    #     # State is Pause-DR
    #     jtag.shift_dr do
    #       # State is Shift-DR
    #     end
    #     # State is Pause-DR
    #   end
    #   # State is Run-Test/Idle
    def shift_dr(options = {})
      validate_state(:idle, :pause_dr)
      log 'Transition to Shift-DR...'
      if state == :idle
        tms!(1)  # => Select-DR-Scan
        update_state :select_dr_scan
        tms!(0)  # => Capture-DR
        update_state :capture_dr
        tms!(0)  # => Shift-DR
        update_state :shift_dr
        if options[:write]
          msg = "Write DR: #{options[:write]}"
        elsif options[:read]
          msg = "Read DR: #{options[:read]}"
        else
          msg = 'DR Data'
        end
        log msg, always: true do
          yield
          log 'Transition to Run-Test/Idle...'
          if @last_data_vector_shifted
            @last_data_vector_shifted = false
          else
            tms!(1)  # => Exit1-DR
            update_state :exit1_dr
          end
        end
        tms!(1)  # => Update-DR
        update_state :update_dr
        tms!(0)  # => Run-Test/Idle
        update_state :idle
      else # :pause_dr
        tms!(1)  # => Exit2-DR
        update_state :exit2_dr
        tms!(0)  # => Shift-DR
        update_state :shift_dr
        yield
        log 'Transition to Pause-DR...'
        tms!(1)  # => Exit1-DR
        update_state :exit1_dr
        tms!(0)  # => Pause-DR
        update_state :pause_dr
      end
    end

    # Goto Pause-DR state then exit back to Run-Test/Idle
    #
    # @example Trandition into Pause-DR
    #   # State is Run-Test/Idle
    #   jtag.pause_dr do
    #     # State is Pause-DR
    #   end
    #   # State is Run-Test/Idle
    #
    # This method can be nested inside of a shift_dr block
    # to transition into the Pause-DR state and then back
    # to Shift-DR
    #
    # @example Switching between Shift-DR and Pause-DR
    #   # State is Run-Test/Idle
    #   jtag.shift_dr do
    #     # State is Shift-DR
    #     jtag.pause_dr do
    #       # State is Pause-DR
    #     end
    #     # State is Shift-DR
    #   end
    #   # State is Run-Test/Idle
    def pause_dr
      validate_state(:idle, :shift_dr)
      log 'Transition to Pause-DR...'
      if state == :idle
        tms!(1)  # => Select-DR-Scan
        update_state :select_dr_scan
        tms!(0)  # => Capture-DR
        update_state :capture_dr
        tms!(1)  # => Exit1-DR
        update_state :exit1_dr
        tms!(0)  # => Pause-DR
        update_state :pause_dr
        yield
        log 'Transition to Run-Test/Idle...'
        tms!(1)  # => Exit2-DR
        update_state :exit2_dr
        tms!(1)  # => Update-DR
        update_state :update_dr
        tms!(0)  # => Run-Test/Idle
        update_state :idle
      else  # shift_dr
        tms!(1)  # => Exit1-DR
        update_state :exit1_dr
        tms!(0)  # => Pause-DR
        update_state :pause_dr
        yield
        log 'Transition to Shift-DR...'
        tms!(1)  # => Exit2-DR
        update_state :exit2_dr
        tms!(0)  # => Shift-DR
        update_state :shift_dr
      end
    end

    # Goto Shift-IR state then exit back to Run-Test/Idle
    #
    # @example Trandition into Shift-IR
    #   # State is Run-Test/Idle
    #   jtag.shift_ir do
    #     # State is Shift-IR
    #   end
    #   # State is Run-Test/Idle
    #
    # This method can be nested inside of a pause_ir block
    # to transition into the Shift-IR state and then back
    # to Pause-IR
    #
    # @example Switching between Pause-IR and Shift-IR
    #   # State is Run-Test/Idle
    #   jtag.pause_ir do
    #     # State is Pause-IR
    #     jtag.shift_ir do
    #       # State is Shift-IR
    #     end
    #     # State is Pause-IR
    #   end
    #   # State is Run-Test/Idle
    def shift_ir(options = {})
      validate_state(:idle, :pause_ir)
      log 'Transition to Shift-IR...'
      if state == :idle
        tms!(1)  # => Select-DR-Scan
        update_state :select_dr_scan
        tms!(1)  # => Select-IR-Scan
        update_state :select_ir_scan
        tms!(0)  # => Capture-IR
        update_state :capture_ir
        tms!(0)  # => Shift-IR
        update_state :shift_ir
        if options[:write]
          msg = "Write IR: #{options[:write]}"
        elsif options[:read]
          msg = "Read IR: #{options[:read]}"
        else
          msg = 'IR Data'
        end
        log msg, always: true do
          yield
          log 'Transition to Run-Test/Idle...'
          if @last_data_vector_shifted
            @last_data_vector_shifted = false
          else
            tms!(1)  # => Exit1-IR
            update_state :exit1_ir
          end
        end
        tms!(1)  # => Update-IR
        update_state :update_ir
        tms!(0)  # => Run-Test/Idle
        update_state :idle
      else # :pause_ir
        tms!(1)  # => Exit2-IR
        update_state :exit2_ir
        tms!(0)  # => Shift-IR
        update_state :shift_ir
        yield
        log 'Transition to Pause-IR...'
        tms!(1)  # => Exit1-IR
        update_state :exit1_ir
        tms!(0)  # => Pause-IR
        update_state :pause_ir
      end
    end

    # Goto Pause-IR state then exit back to Run-Test/Idle
    #
    # @example Trandition into Pause-iR
    #   # State is Run-Test/Idle
    #   jtag.pause_ir do
    #     # State is Pause-IR
    #   end
    #   # State is Run-Test/Idle
    #
    # This method can be nested inside of a shift_ir block
    # to transition into the Pause-IR state and then back
    # to Shift-IR
    #
    # @example Switching between Shift-IR and Pause-IR
    #   # State is Run-Test/Idle
    #   jtag.shift_ir do
    #     # State is Shift-IR
    #     jtag.pause_ir do
    #       # State is Pause-IR
    #     end
    #     # State is Shift-IR
    #   end
    #   # State is Run-Test/Idle
    def pause_ir
      validate_state(:idle, :shift_ir)
      log 'Transition to Pause-IR...'
      if state == :idle
        tms!(1)  # => Select-DR-Scan
        update_state :select_dr_scan
        tms!(1)  # => Select-IR-Scan
        update_state :select_ir_scan
        tms!(0)  # => Capture-IR
        update_state :capture_ir
        tms!(1)  # => Exit1-IR
        update_state :exit1_ir
        tms!(0)  # => Pause-IR
        update_state :pause_ir
        yield
        log 'Transition to Run-Test/Idle...'
        tms!(1)  # => Exit2-IR
        update_state :exit2_ir
        tms!(1)  # => Update-IR
        update_state :update_ir
        tms!(0)  # => Run-Test/Idle
        update_state :idle
      else # :shift_ir
        tms!(1)  # => Exit1-IR
        update_state :exit1_ir
        tms!(0)  # => Pause-IR
        update_state :pause_ir
        yield
        log 'Transition to Shift-IR...'
        tms!(1)  # => Exit2-IR
        update_state :exit2_ir
        tms!(0)  # => Shift-IR
        update_state :shift_ir
      end
    end

    # Returns the current state as a human readable string
    def state_str
      STATES[state]
    end
    alias_method :current_state_str, :state_str

    # Forces the state to Run-Test/Idle regardless of the current
    # state.
    def idle
      log 'Force transition to Run-Test/Idle...'
      # From the JTAG2IPS block guide holding TMS high for 5 cycles
      # will force it to reset regardless of the state, let's give
      # it 6 for luck:
      6.times { tms!(1) }
      # Now a couple of cycles low to get it into idle
      2.times { tms!(0) }
      update_state :idle
    end

    # Force state to Test-Logic-Reset regardless of the current
    # state
    def reset
      log 'Force transition to Test-Logic-Reset...'
      # JTAG reset
      6.times { tms!(1) }
    end

    def update_state(state)
      @state = state
      log "Current state: #{state_str}" if log_state_changes
      @listeners ||= Origen.listeners_for(:on_jtag_state_change)
      @listeners.each { |l| l.on_jtag_state_change(@state) }
    end

    private

    def init_tap_controller(options = {})
      options = {
      }.merge(options)
    end

    # Ensures that the current state matches one of the given acceptable
    # states.
    #
    # Additionally if the current state is unknown and idle is acceptable
    # then the state will be transitioned to idle.
    def validate_state(*acceptable_states)
      if current_state == :unknown && acceptable_states.include?(:idle)
        idle
      elsif acceptable_states.include?(current_state)
        return
      else
        fail 'JTAG TAP Controller - An invalid state sequence has occurred!'
      end
    end

    def log(msg, options = {})
      cc "[JTAG] #{msg}" if verbose? || options[:always]
      if block_given?
        yield
        cc "[JTAG] /#{msg}" if verbose? || options[:always]
      end
    end
  end
end
