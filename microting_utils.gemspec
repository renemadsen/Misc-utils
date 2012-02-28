# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "microting_utils/version"

Gem::Specification.new do |s|
  s.name        = "microting_utils"
  s.version     = MicrotingUtils::VERSION
  s.authors     = ["Cristina Matonte and Guy Silva"]
  s.email       = ["cam@microting.dk"]
  s.homepage    = ""
  s.summary     = %q{Libraries to be used by Microting}
  s.description = %q{Includes libraries like the comparison one}

  s.rubyforge_project = "microting_utils"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  #Development dependencies
  s.add_development_dependency "rake"  
  s.add_development_dependency "rspec"

  #Runtime dependencies
  s.add_runtime_dependency "activesupport", ">=2.3.11"

end
