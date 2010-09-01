module Backup
  module Mail
    class Base
      
      # Sets up the Mail Configuration for the Backup::Mail::Base class.
      # This must be set in order to send emails
      # It will dynamically add class methods (configuration) for each email that will be sent
      def self.setup(config)
        if config
          (class << self; self; end).instance_eval do
            config.attributes.each do |method, value|
              define_method method do
                value
              end
            end
            config.get_smtp_configuration.attributes.each do |method, value|
              define_method method do
                value
              end
            end
          end
        end
      end
      
      # Returns true if the "to" and "from" attributes are set
      def self.setup?
        return true if defined?(from) and defined?(to)
        false
      end
      
      # Delivers the backup details by email to the recipient
      # Requires the Backup Object
      def self.notify!(backup)
        if self.setup? and backup.procedure.attributes['notify'].eql?(true)
          require 'pony'

          @backup = backup
          self.parse_body
          Pony.mail({
            :subject  => "Backup for \"#{@backup.trigger}\" was successfully created!",
            :body     => @content
            }.merge(self.smtp_configuration))
          puts "Sending notification to #{self.to}."
        end
      end
            
      # Retrieves SMTP configuration
      def self.smtp_configuration
        { :to       => self.to,
          :from     => self.from,
          :via      => :smtp,
          :smtp     => {
          :host     => self.host,
          :port     => self.port,
          :user     => self.username,
          :password => self.password,
          :auth     => self.authentication,
          :domain   => self.domain,
          :tls      => self.tls
        }}
      end
      
      def self.parse_body
        File.open(File.join(File.dirname(__FILE__), 'mail.txt'), 'r') do |file|
          self.gsub_content(file.readlines)
        end
      end
      
      def self.gsub_content(lines)
        container = @backup.procedure.get_storage_configuration.attributes['container']
        bucket  = @backup.procedure.get_storage_configuration.attributes['bucket']
        path    = @backup.procedure.get_storage_configuration.attributes['path']
        ip      = @backup.procedure.get_storage_configuration.attributes['ip']
        
        lines.each do |line|
          line.gsub!(':trigger',   @backup.trigger)
          line.gsub!(':day',       Time.now.strftime("%A (%d)"))
          line.gsub!(':month',     Time.now.strftime("%B"))
          line.gsub!(':year',      Time.now.strftime("%Y"))
          line.gsub!(':time',      Time.now.strftime("%r"))
          line.gsub!(':adapter',   @backup.procedure.adapter_name.to_s)
          line.gsub!(':location',  container || bucket || path)
          line.gsub!(':backup',    @backup.final_file)
          case @backup.procedure.storage_name.to_sym
            when :cloudfiles        then line.gsub!(':remote', "on Rackspace Cloudfiles")
            when :s3                then line.gsub!(':remote', "on Amazon S3")
            when :local             then line.gsub!(':remote', "on the local server")
            when :scp, :sftp, :ftp  then line.gsub!(':remote', "on the remote server (#{ip})")
          end
          @content ||= String.new
          @content << line
        end
      end

    end
  end
end
