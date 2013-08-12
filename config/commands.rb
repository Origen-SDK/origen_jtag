# This file should be used to extend the rgen command line tool with tasks 
# specific to your application.
# The comments below should help to get started and you can also refer to
# lib/rgen/commands.rb in your RGen core workspace for more examples and 
# inspiration.
#
# Also see the official docs on adding commands:
#   http://rgen.freescale.net/rgen/latest/guides/custom/commands/

# Map any command aliases here, for example to allow rgen -x to refer to a 
# command called execute you would add a reference as shown below: 
aliases ={
#  "-x" => "execute",
}

# The requested command is passed in here as @command, this checks it against
# the above alias table and should not be removed.
@command = aliases[@command] || @command

def path_to_coverage_report
  require 'pathname'
  Pathname.new("#{RGen.root}/coverage/index.html").relative_path_from(Pathname.pwd)
end

def enable_coverage(name, merge=true)
  if ARGV.delete("-c") || ARGV.delete("--coverage")
    require 'simplecov'
    SimpleCov.start do
      command_name name

      at_exit do
        SimpleCov.result.format!
        puts ""
        puts "To view coverage report:"
        puts "  firefox #{path_to_coverage_report} &"
        puts ""
      end
    end
    yield
  else
    yield
  end
end

# Now branch to the specific task code
case @command

when "examples"  
  RGen.load_application
  enable_coverage("examples") do 

    # Pattern generator tests
    ARGV = %w(jtag_workout -t debug -r approved)
    load "#{RGen.top}/lib/rgen/commands/generate.rb"
    ARGV = %w(jtag_workout -t v93k -r approved)
    load "#{RGen.top}/lib/rgen/commands/generate.rb"
    
    if RGen.app.stats.changed_files == 0 &&
       RGen.app.stats.new_files == 0 &&
       RGen.app.stats.changed_patterns == 0 &&
       RGen.app.stats.new_patterns == 0

      RGen.app.stats.report_pass
    else
      RGen.app.stats.report_fail
    end
    puts ""
  end
  exit 0

# Always leave an else clause to allow control to fall back through to the
# RGen command handler.
# You probably want to also add the command details to the help shown via
# rgen -h, you can do this be assigning the required text to @application_commands
# before handing control back to RGen. Un-comment the example below to get started.
else
  @application_commands = <<-EOT
 examples     Run the examples (tests), -c will enable coverage
  EOT

end 
