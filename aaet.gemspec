# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "#{Dir.pwd}/lib/version"

Gem::Specification.new do |spec|
  spec.name          = "aaet"
  spec.version       = Aaet::VERSION
  spec.authors       = ["isonic1"]
  spec.email         = ["justin.ison@gmail.com"]

  spec.summary       = %q{A CLI to crawl native mobile Android applications with Appium on Devices, Emulators & Cloud Serivces}
  spec.description   = %q{A CLI to collect metadata about an applicaton on every run from the command line}
  spec.homepage      = "https://github.com/isonic1/Appium-Native-Crawler"
  spec.license       = "GPL-3.0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|output|pkg|example|output|runs|reports)/})
  end
  #spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = ["aaet"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_dependency "commander"
  spec.add_dependency "awesome_print"
  spec.add_dependency "colorize"
  spec.add_dependency "faker"
  spec.add_dependency "os"
  spec.add_dependency "pry"
  spec.add_dependency "redic", '~> 1.5.0'
  spec.add_dependency "apktools", '~> 0.7.1'
  spec.add_dependency "parallel", '~> 1.9.0'
  spec.add_dependency "eyes_selenium", '= 3.10.1'
  spec.add_dependency "tilt"
  spec.add_dependency "haml"
  spec.add_dependency "curb"
  spec.add_dependency "httparty"
  spec.add_dependency "toml-rb"
  spec.add_dependency "appium_lib"
  spec.add_dependency "jsonpath"
end