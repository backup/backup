# frozen_string_literal: true
require "spec_helper"

RSpec.describe BackupFog do
  it "has a version number" do
    expect(BackupFog::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(true).to eq(true)
  end
end
