require 'rubygems'
require 'spec'
require 'spec/rake/spectask'
require 'rake/rdoctask'

task :default => :spec

desc "Run all specs"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['spec/**/*.rb']
end

