RSpec.configure do |config|
  config.before do
    # Logs a $stderr message on Thread exceptions. Introduced with Ruby 2.4.
    #
    # Default rubies settings
    # - ruby-2.4.x => Thread.report_on_exception = false
    # - ruby-2.5.x => Thread.report_on_exception = true
    Thread.report_on_exception = true if Thread.respond_to?(:report_on_exception)
  end
end
