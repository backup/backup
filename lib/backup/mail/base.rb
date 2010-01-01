module Backup
  module Mail
    class Base
      
      # Sets up the Mail Configuration for the Backup::Mail::Base class.
      # This must be set in order to send emails
      # It will dynamically add class methods (configuration) for each email that will be sent
      def self.setup(config)
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
      
      # Returns true if the "to" and "from" attributes are set
      def self.setup?
        return true if defined?(from) and defined?(to)
        false
      end
      
      # Delivers the backup details by email to the recipient
      # Requires the Backup Object
      def self.notify!(backup)
        if self.setup?
          @backup = backup          
          Pony.mail({
            :subject  => "Backup for \"#{@backup.trigger}\" was successfully created!",
            :body     => self.parse_body
            }.merge(self.smtp_configuration))
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
          content = self.gsub_content(file.readlines)
        end
        content
      end
      
      def self.gsub_content(content)
        %w(bucket path).each do |value|
          value = @backup.procedure.get_storage_configuration.attributes[value]
        end
        
        content.gsub!(':trigger',   @backup.trigger)
        content.gsub!(':day',       Time.now.strftime("%d (%A)"))
        content.gsub!(':month',     Time.now.strftime("%B (%m)"))
        content.gsub!(':year',      Time.now.strftime("%Y"))
        content.gsub!(':time',      Time.now.strftime("%r"))
        content.gsub!(':adapter',   @backup.procedure.adapter_name.to_s)
        content.gsub!(':location',  bucket || path)
        content.gsub!(':backup',    @backup.final_file)
        content
      end

    end
  end
end