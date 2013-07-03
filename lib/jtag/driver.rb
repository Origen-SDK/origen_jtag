module JTAG
  # JTAG driver, mainly intended for test mode entry on Pioneer based devices.
  #
  # To use this driver the $soc model must define the following pins (an alias is fine):
  #   :tclk
  #   :tmi
  #   :tdo     
  #   :tms     
  #   :trst    # Optional
  #
  # API methods:
  #   jtag_shift
  #   jtag_nonshift
  #   Test_Logic_Reset
  #   Run_Test_Idle
  #   Select_DR
  #   Capture_DR
  #   Shift_DR_Exit1_DR
  #   Exit1_DR
  #   Pause_DR
  #   Exit2_DR
  #   Update_DR
  #   Select_IR
  #   Capture_IR
  #   Shift_IR_Exit1_IR
  #   Exit1_IR
  #   Pause_IR
  #   Exit2_IR
  #   Update_IR
  class Driver

    include RGen::Registers

    attr_accessor :owner

    def initialize(owner)

      if defined?(owner.class::JTAG_CONFIG)
        options = owner.class::JTAG_CONFIG
      else
        options = {}
      end

      # Some default added by SMcG so this thing can boot without options,
      # don't know if they make sense...
      options = {
        :ir_len => 4,
        :tstCtrl_len => 31,
      }.merge(options)

      if options[:ir_len]
      
        #this portion is include for legacy purposes, it should be removed once all pioneer projects
        #  have been moved to new method since this way is too implementation specific.
        @ir_len = options[:ir_len] || 5
        @bnd_len = options[:bnd_len] || 1
        @tstCtrl_len = options[:tstCtrl_len] || 5
        @censorCtrl_len = options[:censorCtrl_len] || 64 
        @dr1_len = options[:dr1_len] || 32
        @dr2_len = options[:dr2_len] || 32
        @verbose = options[:verbose] || false
	
        add_reg :instrReg,  0xFF, @ir_len, :word => { :pos => 0, :bits => @ir_len }

        #add_reg :boundReg,  0x00, @bnd_len, :word => { :pos => 0, :bits => @bnd_len }
        add_reg :dReg0, 0x00, @bnd_len, :word => { :pos => 0, :bits => @bnd_len }
        #add_reg :identReg,  0x01, 32, :word => { :pos => 0, :bits => 32 }
        add_reg :dReg1, 0x01, 32, :word => { :pos => 0, :bits => 32 }
        #add_reg :bypReg,    0x02, 1, :word => { :pos => 0, :bits => 1 }
        add_reg :dReg2, 0x02, 1, :word => { :pos => 0, :bits => 1 }
        #add_reg :bistReg,   0x03, 1, :word => { :pos => 0, :bits => 1 }
        add_reg :dReg3, 0x03, 1, :word => { :pos => 0, :bits => 1 }
        #add_reg :testReg,   0x04, @tstCtrl_len, :word => { :pos => 0, :bits => @tstCtrl_len }
        add_reg :dReg4, 0x04, @tstCtrl_len, :word => { :pos => 0, :bits => @tstCtrl_len }
        #add_reg :censorReg, 0x05, @censorCtrl_len, :word => { :pos => 0, :bits => @censorCtrl_len }
        add_reg :dReg5, 0x05, @censorCtrl_len, :word => { :pos => 0, :bits => @censorCtrl_len }
        #add_reg :data1Reg,  0x06, @dr1_len, :word => { :pos => 0, :bits => @dr1_len }
        add_reg :dReg6, 0x06, @dr1_len, :word => { :pos => 0, :bits => @dr1_len }
        #add_reg :data2Reg,  0x07, @dr2_len, :word => { :pos => 0, :bits => @dr1_len }
        add_reg :dReg7, 0x07, @dr2_len, :word => { :pos => 0, :bits => @dr1_len }
        
        reg(:instrReg).write(1)
        reg(:dReg0).reset
        reg(:dReg1).reset
        reg(:dReg2).reset
        reg(:dReg3).reset
        reg(:dReg4).reset
        reg(:dReg5).reset
        reg(:dReg6).reset
        reg(:dReg7).reset

      else
      
        #this initialization is generic and can be configured in at the soc level for
        # different number of jtag registers with different sizes
        @verbose = options[:verbose] || false

        #instantiate main JTAG Instruction Register
        ir_width = options[:JTAGIRWIDTH]
        add_reg :instrReg,  0xFF, ir_width, :word => { :pos => 0, :bits => ir_width}
        @ir_len = options[:ir_len] || 5
        reg(:instrReg).write(options[:JTAGIRRESETVAL])

        #instantiate JTAG Data Register for each instruction code (some are just virtual)
        dReg_width = Array.new(2^ir_width)
        (2**ir_width).times do |i|
          dReg_width[i] = options[:"ir#{i}_len".to_sym] || 1
        end

        (2**ir_width).times do |i|
          #add_reg :"dReg#{i}".to_sym,  0x00, dReg_width[i], :word => { :pos => 0, :bits => dReg_width[i] }
          add_reg :"dReg#{i}".to_sym,  0x00, dReg_width[i], :word => { :pos => 0, :bits => dReg_width[i] }
          reg("dReg#{i}".to_sym).reset
        end
	
      end
    end
    
    def jtag_shift(size, tms, tdi, tdo, compare=false)
        size.times do |bit|
           $soc.pin(:tclk).drive(0)
           $soc.pin(:tms).drive(tms)
           $soc.pin(:tdi).drive(tdi[bit])
           if(compare)
              $soc.pin(:tdo).expect(tdo[bit])
           else
              $soc.pin(:tdo).dont_care
           end
           $tester.cycle
        end
        $soc.pin(:tdo).dont_care
    end

    def jtag_nonshift(size, tms)
        $soc.pin(:tclk).drive(0)
        $soc.pin(:tms).drive(tms)
        $tester.cycle
    end
    
        
    def Test_Logic_Reset
        jtag_nonshift(1, 1)
        cc "Test_Logic_Reset" if @verbose
    end
    
    def Run_Test_Idle
        jtag_nonshift(1, 0)
        cc "Run_Test_Idle" if @verbose
    end
    
    def Select_DR
        jtag_nonshift(1, 1)
        cc "Select_DR" if @verbose
    end
    
    def Capture_DR
        jtag_nonshift(1, 0)
        cc "Capture_DR" if @verbose
    end
    
    def Shift_DR_Exit1_DR(size, tdi, compare=false)
        # get current DR data (use current IR content to select DR) for compare on shift out
        instr = reg(:instrReg).data
        tmp_tdo = reg("dReg#{instr}".to_sym).data
        cc "DR Shift Out: " + tmp_tdo.to_s(2) if @verbose
	
        jtag_nonshift(1, 0)
        jtag_shift(size-1, 0, tdi, tmp_tdo, compare)
        jtag_shift(1, 1, tdi[size-1], tmp_tdo[size-1], compare)

        # update DR data (use current IR content to select DR) for accuracy on next shift out
        reg("dReg#{instr}".to_sym).write(tdi)
        cc "DR Shifted In: " + reg("dReg#{instr}".to_sym).data.to_s(2) if @verbose
        
        cc "Shift_DR_Exit1_IR" if @verbose    
    end
    
    def Exit1_DR
        jtag_nonshift(1, 1)
        cc "Exit1_DR" if @verbose
    end
    
    def Pause_DR(size=0)
        jtag_nonshift(1, 0)
        jtag_nonshift(size, 0)
        cc "Pause_DR" if @verbose
    end
    
    def Exit2_DR
        jtag_nonshift(1, 1)
        cc "Exit2_DR" if @verbose
    end
    
    def Update_DR
        jtag_nonshift(1, 1)
        cc "Update_DR" if @verbose
    end
    
    def Select_IR
        jtag_nonshift(1, 1)
        cc "Select_IR" if @verbose
    end
    
    def Capture_IR
        jtag_nonshift(1, 0)
        cc "Capture_IR" if @verbose
    end
    
    def Shift_IR_Exit1_IR(size, tdi, compare=false)
        # get current IR data for compare on shift out
        tmp_tdo = reg(:instrReg).data
        cc "IR Shift Out: " + tmp_tdo.to_s(2) if @verbose
	
        jtag_nonshift(1, 0)
        jtag_shift(size-1, 0, tdi, tmp_tdo, compare)
        jtag_shift(1, 1, tdi[size-1], tmp_tdo[size-1], compare)

        # update IR data for accuracy on next shift out
        reg(:instrReg).write(tdi)
        cc "IR Shifted In: " + reg(:instrReg).data.to_s(2) if @verbose
        
        cc "Shift_IR_Exit1_IR" if @verbose
    end
    
    def Exit1_IR
        jtag_nonshift(1, 1)
        cc "Exit1_IR" if @verbose
    end
    
    def Pause_IR(size=0)
        jtag_nonshift(1, 0)
        jtag_nonshift(size, 0)
        cc "Pause_IR" if @verbose
    end
    
    def Exit2_IR
        jtag_nonshift(1, 1)
        cc "Exit2_IR" if @verbose
    end
    
    def Update_IR
        jtag_nonshift(1, 1)
        cc "Update_IR" if @verbose
    end

    def shift_DR_bits(size, tdi, tdo)
        Select_DR()
        Capture_DR()
        if(size)
          Shift_DR_Exit1_DR(size, tdi, tdo);
        else
          Exit1_DR()
        end
        Update_DR()
        Run_Test_Idle()
        cc "jtag_abs_if: shift_DR_bits complete"
    end

    def shift_IR_bits(size, tdi, compare=false)
        Select_DR()
        Select_IR()
        Capture_IR()
        if(size)
	      Shift_IR_Exit1_IR(size, tdi, compare);
        else
	      Exit1_IR()
        end
        Update_IR()
        Run_Test_Idle()
        cc "jtag_abs_if: Shift_IR_bits complete"
    end

    def shift_IR_DR_bits(ir_size, ir, dr_size, dr, dr_out)
        Select_DR()
        Select_IR()
        Capture_IR()
        if(ir_size)
	      Shift_IR_Exit1_IR(ir_size, ir, dr_out);
	    else
	      Exit1_IR()
	    end
        Update_IR()
        Select_DR()
        Capture_DR()
        if(dr_size)
          Shift_DR_Exit1_DR(dr_size, dr, dr_out);
	    else
	      Exit1_DR()
	    end
        Update_DR()
        Run_Test_Idle()
        cc "jtag_abs_if: shift_IR_DR_bits complete"
    end

  end
end
