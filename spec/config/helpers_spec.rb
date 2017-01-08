require "spec_helper"

module Backup
  describe "Config::Helpers" do
    before do
      class Foo
        include Backup::Config::Helpers
        attr_accessor :accessor, :accessor_two
        attr_reader :reader

        attr_deprecate :removed,
          version: "1.1"

        attr_deprecate :removed_with_message,
          version: "1.2",
          message: "This has no replacement."

        attr_deprecate :removed_with_action,
          version: "1.3",
          action: (lambda do |klass, val|
            klass.accessor = val ? "1" : "0"
            klass.accessor_two = "updated"
          end)

        attr_deprecate :removed_with_action_and_message,
          version: "1.4",
          message: "Updating accessors.",
          action: (lambda do |klass, val|
            klass.accessor = val ? "1" : "0"
            klass.accessor_two = "updated"
          end)
      end
    end

    after { Backup.send(:remove_const, "Foo") }

    describe ".defaults" do
      let(:defaults) { mock }

      before do
        Config::Defaults.expects(:new).once.returns(defaults)
      end

      it "should return the Config::Defaults for the class" do
        expect(Foo.defaults).to eq(defaults)
      end

      it "should yield the Config::Defaults for the class" do
        Foo.defaults do |config|
          expect(config).to eq(defaults)
        end
      end

      it "should cache the Config::Defaults for the class" do
        expect(Foo.instance_variable_get(:@defaults)).to be_nil
        expect(Foo.defaults).to be(defaults)
        expect(Foo.instance_variable_get(:@defaults)).to be(defaults)
        expect(Foo.defaults).to be(defaults)
      end
    end

    describe ".clear_defaults!" do
      it "should clear all defaults set" do
        Foo.defaults do |config|
          config.accessor = "foo"
        end
        expect(Foo.defaults.accessor).to eq("foo")

        Foo.clear_defaults!
        expect(Foo.defaults.accessor).to be_nil
      end
    end

    describe ".deprecations" do
      it "should return @deprecations" do
        expect(Foo.deprecations).to be_a(Hash)
        expect(Foo.deprecations.keys.count).to eq(4)
      end

      it "should set @deprecations to an empty hash if not set" do
        Foo.send(:remove_instance_variable, :@deprecations)
        expect(Foo.deprecations).to eq({})
      end
    end

    describe ".attr_deprecate" do
      before { Foo.send(:remove_instance_variable, :@deprecations) }

      it "should add deprected attributes" do
        Foo.send :attr_deprecate, :attr1
        Foo.send :attr_deprecate, :attr2, version: "2"
        Foo.send :attr_deprecate, :attr3, version: "3", message: "attr3 message"
        Foo.send :attr_deprecate, :attr4, version: "4", message: "attr4 message",
          action: "attr4 action"

        expect(Foo.deprecations).to eq(
          attr1: {
            version: nil,
            message: nil,
            action: nil
          },
          attr2: {
            version: "2",
            message: nil,
            action: nil
          },
          attr3: {
            version: "3",
            message: "attr3 message",
            action: nil
          },
          attr4: {
            version: "4",
            message: "attr4 message",
            action: "attr4 action"
          }
        )
      end
    end

    describe ".log_deprecation_warning" do
      context "when no message given" do
        it "should log a warning that the attribute has been removed" do
          Logger.expects(:warn).with do |err|
            expect(err.message).to eq "Config::Error: [DEPRECATION WARNING]\n" \
              "  Backup::Foo#removed has been deprecated as of backup v.1.1"
          end

          deprecation = Foo.deprecations[:removed]
          Foo.log_deprecation_warning(:removed, deprecation)
        end
      end

      context "when a message is given" do
        it "should log warning with the message" do
          Logger.expects(:warn).with do |err|
            expect(err.message).to eq "Config::Error: [DEPRECATION WARNING]\n" \
              "  Backup::Foo#removed_with_message has been deprecated " \
              "as of backup v.1.2\n" \
              "  This has no replacement."
          end

          deprecation = Foo.deprecations[:removed_with_message]
          Foo.log_deprecation_warning(:removed_with_message, deprecation)
        end
      end
    end # describe '.log_deprecation_warning'

    describe "#load_defaults!" do
      let(:klass) { Foo.new }

      it "should load default values set for the class" do
        Foo.defaults do |config|
          config.accessor = "foo"
        end

        klass.send(:load_defaults!)
        expect(klass.accessor).to eq("foo")
      end

      it "should protect default values" do
        default_value = "foo"
        Foo.defaults do |config|
          config.accessor = default_value
          config.accessor_two = 5
        end

        klass.send(:load_defaults!)
        expect(klass.accessor).to eq("foo")
        expect(klass.accessor).to_not be(default_value)
        expect(klass.accessor_two).to eq(5)
      end

      it "should raise an error if defaults are set for attribute readers" do
        Foo.defaults do |config|
          config.reader = "foo"
        end

        expect do
          klass.send(:load_defaults!)
        end.to raise_error(NoMethodError, /Backup::Foo/)
      end

      it "should raise an error if defaults were set for invalid accessors" do
        Foo.defaults do |config|
          config.foobar = "foo"
        end

        expect do
          klass.send(:load_defaults!)
        end.to raise_error(NoMethodError, /Backup::Foo/)
      end
    end

    describe "#method_missing" do
      context "when the method is a deprecated method" do
        before do
          Logger.expects(:warn).with(instance_of(Config::Error))
        end

        context "when an :action is specified" do
          it "should call the :action" do
            value = [true, false].sample
            expected_value = value ? "1" : "0"

            klass = Foo.new
            klass.removed_with_action = value

            expect(klass.accessor).to eq(expected_value)
            # lambda additionally sets :accessor_two
            expect(klass.accessor_two).to eq("updated")
          end
        end

        context "when no :action is specified" do
          it "should only log the warning" do
            Foo.any_instance.expects(:accessor=).never

            klass = Foo.new
            klass.removed = "foo"

            expect(klass.accessor).to be_nil
          end
        end
      end

      context "when the method is not a deprecated method" do
        it "should raise a NoMethodError" do
          Logger.expects(:warn).never

          klass = Foo.new
          expect do
            klass.foobar = "attr_value"
          end.to raise_error(NoMethodError)
        end
      end

      context "when the method is not a set operation" do
        it "should raise a NoMethodError" do
          Logger.expects(:warn).never

          klass = Foo.new
          expect do
            klass.removed
          end.to raise_error(NoMethodError)
        end
      end
    end # describe '#method_missing'
  end

  describe "Config::Defaults" do
    let(:defaults) { Config::Defaults.new }

    before do
      defaults.foo = "one"
      defaults.bar = "two"
    end

    it "should return nil for unset attributes" do
      expect(defaults.foobar).to be_nil
    end

    describe "#_attribues" do
      it "should return an array of attribute names" do
        expect(defaults._attributes).to be_an Array
        expect(defaults._attributes.count).to eq(2)
        expect(defaults._attributes).to include(:foo, :bar)
      end
    end

    describe "#reset!" do
      it "should clear all attributes set" do
        defaults.reset!
        expect(defaults._attributes).to be_an Array
        expect(defaults._attributes).to be_empty
        expect(defaults.foo).to be_nil
        expect(defaults.bar).to be_nil
      end
    end
  end
end
