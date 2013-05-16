# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Hooks do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }

  describe "#before!" do
    it "accepts model as first arg" do
      m = nil
      h = Backup::Hooks.new(model) do
        before do |a|
          m = a
        end
      end

      h.before!
      m.should == model
    end
  end
  describe "#after!" do
    it "accepts model as first arg" do
      m = nil
      h = Backup::Hooks.new(model) do
        after do |a|
          m = a
        end
      end

      h.after!
      m.should == model
    end
  end
end

