# frozen_string_literal: true

require "bashcov"

Bashcov.parse_options!(ARGV)

require "bashcov/runner"
require "io/nonblock"

blocking_pipe = Module.new do
  define_method(:initialize) do |field_stream|
    super(field_stream)
    @write.nonblock = false
  end
end
Bashcov::Xtrace.prepend(blocking_pipe)

Thread.report_on_exception = false
runner = Bashcov::Runner.new(Bashcov.command)
status, coverage = File.open(File.join(Bashcov.root_directory, "coverage", "bashcov-warnings.log"), "a") do |quiet|
  original_stderr = $stderr
  $stderr = quiet
  [runner.run, runner.result]
ensure
  $stderr = original_stderr
end

require "simplecov"

SimpleCov.print_error_status = false
SimpleCov.start
SimpleCov.command_name(Bashcov.command_name)
SimpleCov.root(Bashcov.root_directory)
SimpleCov::ResultMerger.store_result(SimpleCov::Result.new(coverage))
SimpleCov.at_exit { :quiet }

exit(status.exitstatus)
