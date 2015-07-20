# This file defines the users associated with your project, it is basically the 
# mailing list for release notes.
#
# You can split your users into "admin" and "user" groups, the main difference 
# between the two is that admin users will get all tag emails, users will get
# emails on external/official releases only.
#
# Users are also prohibited from running the "origen tag" task, but this is 
# really just to prevent a casual user from executing it inadvertently and is
# not intended to be a serious security gate.
module Origen
  module Users
    def users
      @users ||= [

        # Admins
        User.new("Stephen McGinty", "r49409", :admin),
        User.new("Chris Nappi", "ra5809", :admin),
        User.new("TS Chung", "rhk462", :admin),
        User.new("Ronnie Lajaunie", "b01784", :admin),
        User.new("Daniel Hadad", "ra6854", :admin),
        User.new("Robert Kang", "b02441", :admin),
        User.new("Stephen Traynor", "r28728", :admin),
        User.new("Elissavet Papadima", "b50264", :admin),
        User.new("Corey Engelken", "b50956", :admin),
        User.new("Jiang Liu", "b20251", :admin),
        # Users
        #User.new("Thao Huynh", "r6aanf"),
        # The r-number attribute can be anything that can be prefixed to an 
        # @freescale.com email address, so you can add mailing list references
        # as well like this:
        #User.new("Origen Users", "origen"),  # The Origen mailing list
        
      ]
    end
  end
end
