# frozen_string_literal: true
require "spec_helper"

RSpec.describe Backup::Fog do
  it "has a version number" do
    expect(Backup::Fog::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(true).to eq(true)
  end
end
