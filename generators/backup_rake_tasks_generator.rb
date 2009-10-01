class BackupRakeTasksGenerator < Rails::Generator::Base

  # This method gets initialized when the generator gets run.
  # It will receive an array of arguments inside @args
  def initialize(runtime_args, runtime_options = {})
    super
    extract_args
    set_defaults
    confirm_input
  end
  
  # Processes the file generation/templating
  # This will automatically be run after the initialize method
  def manifest
    record do |m|
      m.directory "lib/tasks/"
      m.directory "lib/tasks/backup"
      m.file      "README",   "lib/tasks/backup/README"
      m.file      "s3.rake",  "lib/tasks/backup/s3.rake"
      m.file      "ssh.rake", "lib/tasks/backup/ssh.rake"
    end
  end
  
  # Creates a new Hash Object containing the user input
  # The user input will be available through @input and input
  def extract_args
    @input = Hash.new
    @args.each do |arg|
      if arg.include?(":") then
        @input[:"#{arg.slice(0, arg.index(":"))}"] = arg.slice((arg.index(":") + 1)..-1)
      end
    end
  end
  
  # Input Method that's available inside the generated templates
  # because instance variable are not available, so we access them through methods
  def input
    @input
  end

  # Sets defaults for user input when left blank by the user
  # for each parameter
  def set_defaults
  end
  
  # Confirms whether the model and attachment arguments were passed in
  # Raises an error if not
  def confirm_input
  end
  
  private
  
  def input_error
  end
  
end