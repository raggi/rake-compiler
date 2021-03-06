#--
# Cross-compile ruby, using Rake
#
# This source code is released under the MIT License.
# See LICENSE file for details
#++

#
# This code is inspired and based on notes from the following sites:
#
# http://tenderlovemaking.com/2008/11/21/cross-compiling-ruby-gems-for-win32/
# http://github.com/jbarnette/johnson/tree/master/cross-compile.txt
# http://eigenclass.org/hiki/cross+compiling+rcovrt
#
# This recipe only cleanup the dependency chain and automate it.
# Also opens the door to usage different ruby versions 
# for cross-compilation.
#

require 'rake'
require 'rake/clean'
require 'yaml'

USER_HOME = File.expand_path("~/.rake-compiler")
RUBY_CC_VERSION = "ruby-#{ENV['VERSION'] || '1.8.6-p287'}"

# grab the major "1.8" or "1.9" part of the version number
MAJOR = RUBY_CC_VERSION.match(/.*-(\d.\d).\d/)[1]

# Sorry!
# On some systems (linux) you get i586 targets, on others i386 targets, at 
# present, I only know to search for them.
compilers = %w(i586-mingw32msvc-gcc i386-mingw32-gcc)
paths = ENV['PATH'].split(File::PATH_SEPARATOR)
compiler = compilers.find do |comp|
  paths.find do |path|
    File.exist? File.join(path, comp)
  end
end
MINGW_HOST = compiler[0..-5]

# define a location where sources will be stored
directory "#{USER_HOME}/sources/#{RUBY_CC_VERSION}"
directory "#{USER_HOME}/builds/#{RUBY_CC_VERSION}"

# clean intermediate files and folders
CLEAN.include("#{USER_HOME}/sources/#{RUBY_CC_VERSION}")
CLEAN.include("#{USER_HOME}/builds/#{RUBY_CC_VERSION}")

# remove the final products and sources
CLOBBER.include("#{USER_HOME}/sources")
CLOBBER.include("#{USER_HOME}/builds")
CLOBBER.include("#{USER_HOME}/ruby/#{RUBY_CC_VERSION}")
CLOBBER.include("#{USER_HOME}/config.yml")

# ruby source file should be stored there
file "#{USER_HOME}/sources/#{RUBY_CC_VERSION}.tar.gz" => ["#{USER_HOME}/sources"] do |t|
  # download the source file using wget or curl
  chdir File.dirname(t.name) do
    url = "ftp://ftp.ruby-lang.org/pub/ruby/#{MAJOR}/#{File.basename(t.name)}"
    sh "wget #{url} || curl -O #{url}"
  end
end

# Extract the sources
file "#{USER_HOME}/sources/#{RUBY_CC_VERSION}" => ["#{USER_HOME}/sources/#{RUBY_CC_VERSION}.tar.gz"] do |t|
  chdir File.dirname(t.name) do
    t.prerequisites.each { |f| sh "tar xfz #{File.basename(f)}" }
  end
end

# backup makefile.in
file "#{USER_HOME}/sources/#{RUBY_CC_VERSION}/Makefile.in.bak" => ["#{USER_HOME}/sources/#{RUBY_CC_VERSION}"] do |t|
  cp "#{USER_HOME}/sources/#{RUBY_CC_VERSION}/Makefile.in", t.name
end

# correct the makefiles
file "#{USER_HOME}/sources/#{RUBY_CC_VERSION}/Makefile.in" => ["#{USER_HOME}/sources/#{RUBY_CC_VERSION}/Makefile.in.bak"] do |t|
  content = File.open(t.name, 'rb') { |f| f.read }

  out = ""

  content.each_line do |line|
    if line =~ /^\s*ALT_SEPARATOR =/
      out << "\t\t    ALT_SEPARATOR = \"\\\\\\\\\"; \\\n"
    else
      out << line
    end
  end

  when_writing("Patching Makefile.in") {
    File.open(t.name, 'wb') { |f| f.write(out) }
  }
end

task :mingw32 do
  unless MINGW_HOST then
    warn "You need to install mingw32 cross compile functionality to be able to continue."
    warn "Please refer to your distro documentation about installation."
    fail
  end
end

task :environment do
  ENV['ac_cv_func_getpgrp_void'] =  'no'
  ENV['ac_cv_func_setpgrp_void'] = 'yes'
  ENV['rb_cv_negative_time_t'] = 'no'
  ENV['ac_cv_func_memcmp_working'] = 'yes'
  ENV['rb_cv_binary_elf' ] = 'no'
end

# generate the makefile in a clean build location
file "#{USER_HOME}/builds/#{RUBY_CC_VERSION}/Makefile" => ["#{USER_HOME}/builds/#{RUBY_CC_VERSION}",
                                  "#{USER_HOME}/sources/#{RUBY_CC_VERSION}/Makefile.in"] do |t|

  # set the configure options
  options = [
    "--host=#{MINGW_HOST}",
    '--target=i386-mingw32',
    '--build=i686-linux',
    '--enable-shared'
  ]

  chdir File.dirname(t.name) do
    prefix = File.expand_path("../../ruby/#{RUBY_CC_VERSION}")
    options << "--prefix=#{prefix}"
    sh File.expand_path("../../sources/#{RUBY_CC_VERSION}/configure"), *options
  end
end

# make
file "#{USER_HOME}/builds/#{RUBY_CC_VERSION}/ruby.exe" => ["#{USER_HOME}/builds/#{RUBY_CC_VERSION}/Makefile"] do |t|
  chdir File.dirname(t.prerequisites.first) do
    sh "make"
  end
end

# make install
file "#{USER_HOME}/ruby/#{RUBY_CC_VERSION}/bin/ruby.exe" => ["#{USER_HOME}/builds/#{RUBY_CC_VERSION}/ruby.exe"] do |t|
  chdir File.dirname(t.prerequisites.first) do
    sh "make install"
  end
end

# rbconfig.rb location
file "#{USER_HOME}/ruby/#{RUBY_CC_VERSION}/lib/ruby/#{MAJOR}/i386-mingw32/rbconfig.rb" => ["#{USER_HOME}/ruby/#{RUBY_CC_VERSION}/bin/ruby.exe"]

file :update_config => ["#{USER_HOME}/ruby/#{RUBY_CC_VERSION}/lib/ruby/#{MAJOR}/i386-mingw32/rbconfig.rb"] do |t|
  config_file = "#{USER_HOME}/config.yml"
  if File.exist?(config_file) then
    puts "Updating #{t.name}"
    config = YAML.load_file(config_file)
  else
    puts "Generating #{t.name}"
    config = {}
  end

  config["rbconfig-#{MAJOR}"] = File.expand_path(t.prerequisites.first)

  when_writing("Saving changes into #{config_file}") {
    File.open(config_file, 'w') do |f|
      f.puts config.to_yaml
    end
  }
end

task :default do
end

desc "Build #{RUBY_CC_VERSION} suitable for cross-platform development."
task 'cross-ruby' => [:mingw32, :environment, :update_config]
