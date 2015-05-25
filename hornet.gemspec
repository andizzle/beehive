Gem::Specification.new do |spec|
  spec.name               = "hornet"
  spec.version            = "0.0.1.pre"
  spec.default_executable = "hornet"

  spec.author      = "Andy Zhang"
  spec.email       = 'andizzle.zhang@gmail.com'
  spec.homepage    = 'https://github.com/andizzle/hornet'
  spec.license     = 'MIT'
  spec.date        = '2015-05-25'

  spec.description = 'Stress test your web apps.'
  spec.summary     = 'Launch EC2 micro instances, each instance creates multiple docker containers to stress test your web applications.'
  spec.files       = ["lib/hornet.rb", "lib/hornet/hive.rb", "lib/hornet/hq.rb", "lib/hornet/report.rb", "bin/hornet"]

  spec.add_runtime_dependency 'aws-sdk', '~> 1.1'
  spec.add_runtime_dependency 'net-ssh', '~> 2.9'
end
