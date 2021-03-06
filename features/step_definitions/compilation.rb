Given /^a extension named '(.*)'$/ do |extension_name|
  generate_extension_task_for extension_name
  generate_source_code_for extension_name
end

Given /^a extension cross-compilable '(.*)'$/ do |extension_name|
  generate_cross_compile_extension_task_for extension_name
  generate_source_code_for extension_name
end

Given /^a extension '(.*)' with forced platform '(.*)'$/ do |extension_name, forced_platform|
  generate_extension_task_for extension_name, forced_platform
  generate_source_code_for extension_name
end

Given /^that all my source files are in place$/ do
  Given "a safe project directory"
  Given "a extension cross-compilable 'extension_one'"
end

Given /^that my gem source is all in place$/ do
  Given "a safe project directory"
  Given "a gem named 'gem_abc'"
  Given "a extension cross-compilable 'extension_one'"
end

Given /^not changed any file since$/ do
  # don't do anything, that's the purpose of this step!
end

When /^touching '(.*)' file of extension '(.*)'$/ do |file, extension_name|
  Kernel.sleep 1
  FileUtils.touch "ext/#{extension_name}/#{file}"
end

Then /^binary extension '(.*)' (do|do not) exist in '(.*)'$/ do |extension_name, condition, folder|
  ext_for_platform = File.join(folder, "#{extension_name}.#{RbConfig::CONFIG['DLEXT']}")
  if condition == 'do'
    File.exist?(ext_for_platform).should be_true
  else
    File.exist?(ext_for_platform).should be_false
  end
end
