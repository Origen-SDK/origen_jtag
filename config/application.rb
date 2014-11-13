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

  config.semantically_version = true

  config.min_required_rgen_version = "v2.3.0.dev144"

  config.max_required_rgen_version = "v2.99.99"

  config.lint_test = {
    # Require the lint tests to pass before allowing a release to proceed
    run_on_tag: true,
    # Auto correct violations where possible whenever 'rgen lint' is run
    auto_correct: true, 
    # Limit the testing for large legacy applications
    #level: :easy,
    # Run on these directories/files by default
    #files: ["lib", "config/application.rb"],
  }

  # Ensure that all tests pass before allowing a release to continue
  def validate_release
    if !system("rgen examples") #|| !system("rgen specs")
      puts "Sorry but you can't release with failing tests, please fix them and try again."
      exit 1
    else
      puts "All tests passing, proceeding with release process!"
    end
  end

  # Run code coverage when deploying the web site
  def before_deploy_site
    Dir.chdir RGen.root do
      system "rgen examples -c"
      dir = "#{RGen.root}/web/output/coverage"       
      FileUtils.remove_dir(dir, true) if File.exists?(dir) 
      system "mv #{RGen.root}/coverage #{dir}"
    end
  end
 
  # Deploy the website automatically after a production tag
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
