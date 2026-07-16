# frozen_string_literal: true

require "spec_helper"

# The CLI's `comment list` and `card show` commands call `Time.parse`, which is
# provided by the `time` stdlib. If nothing requires "time", those commands crash
# with `undefined method 'parse' for Time:Class`.
#
# This must run in a subprocess: the test suite loads webmock, which transitively
# requires "time", so an in-process check would always pass and hide the bug.
RSpec.describe "Time.parse availability" do
  lib = File.expand_path("../../lib", __dir__)

  it "is available after loading the CLI" do
    script = 'require "trello_cli/cli"; exit(Time.respond_to?(:parse) ? 0 : 1)'
    system("ruby", "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
    expect($?.exitstatus).to eq(0)
  end
end
