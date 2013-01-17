require "formula"

class Nsca < Formula
  homepage "http://exchange.nagios.org/directory/Addons/Passive-Checks/NSCA--2D-Nagios-Service-Check-Acceptor/details"
  url "http://downloads.sourceforge.net/project/nagios/nsca-2.x/nsca-2.7.2/nsca-2.7.2.tar.gz"
  sha1 "95e0778580b235ed47f0294ab9ef669c37f972dd"

  depends_on "nagios"
  
  def nagios_var_lib_rw;  var.join("lib/nagios/rw");        end
  def etc_nagios;         etc.join("nagios");               end
  def nsca_cfg_file;      etc_nagios.join("nsca.cfg");      end
  def send_nsca_cfg_file; etc_nagios.join("send_nsca.cfg"); end
  def user;         `id -un`.chomp;         end
  def group;        `id -gn`.chomp;         end
  
  def install
    configure_and_make
    copy_files
    setting_up_nsca_cfg_file
  end
  
  # it will work only if 
  def on_uninstall
    puts "  Removing nsca and send_nsca config files from #{etc_nagios} directory..."

    rm nsca_cfg_file if nsca_cfg_file.exist?
    rm send_nsca_cfg_file if send_nsca_cfg_file.exist?
  end
  
  def copy_files
    bin.install "src/nsca"
    bin.install "src/send_nsca"
    
    Dir["sample-config/*.cfg"].each do |file| 
      cp file, etc_nagios
    end
  end
  
  def configure_and_make
    system "./configure", "--disable-debug", "--disable-dependency-tracking", "--prefix=#{prefix}"

    system "make all"
  end
  
  def setting_up_nsca_cfg_file
    inreplace nsca_cfg_file do |s|
      s.change_make_var! 'command_file', nagios_var_lib_rw/"nagios.cmd"
      s.change_make_var! 'alternate_dump_file', nagios_var_lib_rw/"nsca.dump"
      s.change_make_var! 'nsca_user', user
      s.change_make_var! 'nsca_group', group
    end
  end
  
  def check_dummy_command
    <<-EOF.undent
      # 'check_dummy' command definition, for NSCA
      define command {
              command_name check_dummy
              command_line $USER1$/check_dummy $ARG1$
      }
    EOF
  end
  
  def passive_service_service
    <<-EOF.undent
      # Define a passive check template
      define service {
              use                     generic-service
              name                     passive_service
              active_checks_enabled   0
              passive_checks_enabled   1 # We want only passive checking
              flap_detection_enabled   0
              register                 0 # This is a template, not a real service
              is_volatile             0
              check_period             24x7
              max_check_attempts       1
              normal_check_interval   5
              retry_check_interval     1
              check_freshness         0
              contact_groups           admins
              check_command           check_dummy!0
              notification_interval   120
              notification_period     24x7
              notification_options     w,u,c,r
              stalking_options         w,c,u
              }
    EOF
  end
  
  def caveats
    <<-EOF.undent
    Apply the below settings at Nagios config files on "#{etc_nagios}" directory
    
    Read at http://nagios.sourceforge.net/download/contrib/documentation/misc/NSCA_Setup.pdf
    to learn more about nsca setup.
    
    You must create a service definition, like below:

    # at #{etc_nagios/:object/'localhost.cfg'}
    define service {
        use passive_service
        service_description TestMessage
        host_name localhost
        }
    
    To start NSCA daemon
      $ nsca -d #{nsca_cfg_file}


    EOF
  end
  
  test do
    HOMEBREW_REPOSITORY.cd do
      `#{bin}/nsca --version` =~ /NSCA/
    end
  end
end
