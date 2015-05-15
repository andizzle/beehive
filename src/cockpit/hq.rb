require 'aws-sdk'

class Hq

  @command = nil
  @options = {}
  @region = 'us-east-1d'

  def initialize(command, options={})
    @command = command
    @options = options
  end

  def dispatch
    case @command
    when 'up'
      createHives(@options)
    end
  end

  def createHives(options)
    puts Aws.config
  end
end
