## Welcome to RGen

RGen is a semiconductor engineering framework with particular focus on test
engineering.

It includes everything required to build complex engineering environments and
provides support for generating test programs, test patterns, dynamically
generated IP of any kind and documentation. It also provides many utilities for
common tasks such as sending emails and interfacing with DesignSync or PDM.

## Getting Started

1. Create a new application.
   Type the following at the command prompt:

       rgen new myapp    (where myapp is the application name)

   To include some example code in the new app add the --examples switch:

       rgen new myapp --examples

2. Change directory to myapp and start developing. If the examples were included
   they can be run using the following commands:

       rgen t example    (select the example target)

       rgen g list/production.list  (generate the example patterns)

       rgen c templates/example.txt.erb  (compile the example template)


3. To get help on RGen go to the official documentation:
   http://rgen.freescale.net. 

4. If you have questions please ask them in the RGen Freeshare community forum:
   http://freeshare.freescale.net:2222/public/rgen-cmty-svc

## Description of Contents

The default directory structure of an RGen application:

    |-- config
    |   |-- application.rb
    |   |-- commands.rb
    |   |-- environment.rb
    |   |-- pdm_component.rb
    |   |-- users.rb
    |   |-- version.rb
    |-- doc
    |   |--history
    |-- lib
    |-- pattern
    |-- program
    |-- targets
    |-- templates
    |   |-- web
    |-- vendor
        |--lib

**config**

Holds all configuration information for your application

**config/application.rb**

This is the main configuration file where the behavior of RGen can be tailored
to the needs of your application. The default settings are usually sufficient
until your application becomes more advanced.

**config/commands.rb**

Custom rgen commands can be added to your application, this is the preferred
way of distributing any scripts required to support your application to your
users. See the docs for details:
http://rgen.freescale.net/rgen/latest/guides/custom/commands/

**config/environment.rb**

This file will be called by RGen to load your application environment, any files
that you add to the lib directory should be loaded from here.

**config/pdm_component.rb**

If you want to maintain a PDM component for your application then RGen can release
to it automatically based on the definition in this file. See the docs for
full details: http://rgen.freescale.net/rgen/latest/guides/pdm/introduction/

**config/users.rb**

Define your application users here, this is basically your mailing list for
release notices.

**config/version.rb**

Defines the current application version. This file is managed by RGen via the
'rgen tag' command and should generally never be edited by hand. The one exception
is if you want to change your application from the default timestamp based tags
to semantic versioning.

**doc**

Any documentation related to your application can be stored here.

**doc/history**

A rolling log of your application tags and release notes is maintained here. A
new entry is generated every time the 'rgen tag' command is run. This file is
pre-formatted to look good when displayed as a web page.

**lib**

All of your application models and logic should go in here. This folder is
already added to Ruby's load path by RGen. Sub-folders can be used as desired
to keep things organized. The contents of this folder will be accessible by
any other applications which import this application.

**pattern**

All test pattern sources should go in here.

**program**

All test program sources should go in here.

**target**

A target defines which silicon design and/or test platform is being targeting
by the generated content. All target definitions live in here.

**templates**

All IP templates should reside here, normally in sub-directories to separate
them by type - e.g. templates/j750, templates/bench_code, templates/rtl, etc.

**templates/web**

Web based documentation of your project should reside here. RGen makes it easy
to produce dynamic documentation based on your application target
configurations. See http://rgen.freescale.net for an example of the kind of
documentation that can be produced.

**vendor/lib**

External libraries that your application depends on can go in here - i.e. any
code which you need to include but which is not owned by you. This directory
is also included in Ruby's load path automatically by RGen.
