class JTAG_Application < RGen::Application

  # This file contains examples of some of the most common configuration options,
  # to see a real production example from a large application have a look at:
  # sync://sync-15088:15088/Projects/common_tester_blocks/blocks/C90TFS_NVM_tester/tool_data/rgen_v2/config/application.rb

  # This information is used in headers and email templates, set it specific
  # to your application
  config.name     = "JTAG"
  config.initials = "JTAG"
  config.vault    = "sync://sync-15088:15088/Projects/common_tester_blocks/rgen_blocks/physical/JTAG/tool_data/rgen" 

  # To enable deployment of your documentation to a web server (via the 'rgen web'
  # command) fill in these attributes. The example here is configured to deploy to
  # the rgen.freescale.net domain, which is an easy option if you don't have another
  # server already in mind. To do this you will need an account on CDE and be a member
  # of the 'rgen' group.
  config.web_directory = "/proj/.web_rgen/html/jtag"
  config.web_domain = "http://rgen.freescale.net/jtag"

  # RGen applications can import the libraries of other applications to share models,
  # define imports like this:
  #config.imports = [
  #  {
  #    :vault => "sync://sync-15088:15088/Projects/common_tester_blocks/rgen_support",
  #    :version => "sm_2013_06_10_11_27",
  #    # The actual application can live at the root of the above vault reference, or
  #    # else within tool_data/rgen. If the app lives at a different path that can
  #    # be specified like this:
  #    #:app_path => "tool_data/rgen_v2",
  #    # When developing it can be useful to have a permanent view of a local
  #    # copy of a dependent application, set that up by supplying a path. RGen will
  #    # not allow the use of the path in production mode, nor will it allow a tag
  #    # when an import is specified via a path.
  #    #:path => "/proj/.mem_c90tfs_testeng/r49409/rgen/rgen_support",
  #  },
  #  {
  #    # Define as many imports as required...
  #  }
  #]

  # Versioning is based on a timestamp by default, if you would rather use semantic
  # versioning, i.e. v1.0.0 format, then set this to true.
  # In parallel go and edit config/version.rb to enable the semantic version code.
  config.semantically_version = true

  # You can map moo numbers to targets here, this allows targets to be selected via
  # rgen t <moo>
  #config.production_targets = {
  #  "1m79x" => "production",
  #}

  # Specifiy a specific version of rgen that must be used with this application, rgen
  # will then enforce that every user's rgen version is correct at runtime
  config.required_rgen_version = "v2.0.1.dev88"

  # An example of how to set application specific LSF parameters
  #config.lsf.project = "msg.te"
  
  # An exmaple of how to specify a prefix to add to all generated patterns
  #config.pattern_prefix = "nvm"

  # An example of how to add header comments to all generated patterns
  #config.pattern_header do
  #  cc "This is a pattern created by the example rgen application"
  #end

  # By default all generated output will end up in ./output.
  # Here you can specify an alternative directory entirely, or make it dynamic such that
  # the output ends up in a setup specific directory. 
  #config.output_directory do
  #  "#{RGen.root}/output/#{$dut.class}"
  #end

  # Similary for the reference files, generally you want to setup the reference directory
  # structure to mirror that of your output directory structure.
  #config.reference_directory do
  #  "#{RGen.root}/.ref/#{$dut.class}"
  #end

  # To enabled source-less pattern generation create a class (for example PatternDispatcher)
  # to generate the pattern. This should return false if the requested pattern has been
  # dispatched, otherwise RGen will proceed with looking up a pattern source as normal.
  #def before_pattern_lookup(requested_pattern)
  #  PatternDispatcher.new.dispatch_or_return(requested_pattern)
  #end

  # If you use pattern iterators you may come accross the case where you request a pattern
  # like this:
  #   rgen g example_pat_b0.atp
  #
  # However it cannot be found by RGen since the pattern name is actually example_pat_bx.atp
  # In the case where the pattern cannot be found RGen will pass the name to this translator
  # if it exists, and here you can make any substitutions to help RGen find the file you 
  # want. In this example any instances of _b\d, where \d means a number, are replaced by
  # _bx.
  #config.pattern_name_translator do |name|
  #  name.gsub(/_b\d/, "_bx")
  #end
  
  def after_release_email(tag, note, type, selector, options)
    deployer = RGen.app.deployer
    if deployer.running_on_cde? && deployer.user_belongs_to_rgen?
      command = "rgen web compile --remote --api"
      if RGen.app.version.production?
        command += " --archive #{RGen.app.version}"
      end
      Dir.chdir RGen.root do
        system command
      end
    end 
  end

end
