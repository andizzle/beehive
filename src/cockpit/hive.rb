require 'net/ssh'

class Hive

  def initialize(username, key, ip, instance_id)
    @username = username
    @key = ::File.expand_path('~/.ssh/%s.pem' % key)
    @ip = ip
    @instance_id = instance_id
  end

  def attack(option)
    ::Net::SSH.start(@ip, @username, :keys => [@key]) do |ssh|
      b_no = 1
      attacks = []
      option[:bees].to_i.times do
        option[:b_no] = b_no
        benchmark_command = 'ab -r -n %{number} -c %{concurrent} -e /root/%{b_no}.csv "%{url}"' % option
        puts "Bee %s-%s has started the attack!\n" % [@instance_id, b_no]
        ssh.open_channel do |cha|
          cha.exec 'docker run -v /home/ubuntu/results:/root andizzle/debian %s' % benchmark_command do |ch, success|
            raise "could not execute command" unless success
            # "on_data" is called when the process writes something to stdout
            ch.on_data do |c, data|
              #$stdout.print "Bee %s-%s has started the attack!\n" % [@instance_id, b_no]
            end
            ch.on_close {
              ssh.exec 'docker ps -aq -f status=exited | xargs docker rm'
              puts "done!"
            }
          end
        end
        b_no += 1
      end
      attacks.each do |attack|
        attack.wait
      end
    end
  end

end
