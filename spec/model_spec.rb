require "spec_helper"

describe "Backup::Model" do
  let(:model) { Backup::Model.new(:test_trigger, "test label") }
  let(:s)     { sequence "" }

  before { Backup::Model.send(:reset!) }
  after { Backup::Model.send(:reset!) }

  describe ".all" do
    it "should be an empty array by default" do
      expect(Backup::Model.all).to eq([])
    end
  end

  describe ".find_by_trigger" do
    before do
      [:one, :two, :three, :one].each_with_index do |sym, i|
        Backup::Model.new("trigger_#{sym}", "label#{i + 1}")
      end
    end

    it "should return an array of all models matching the trigger" do
      models = Backup::Model.find_by_trigger("trigger_one")
      expect(models).to be_a(Array)
      expect(models.count).to be(2)
      expect(models[0].label).to eq("label1")
      expect(models[1].label).to eq("label4")
    end

    it "should return an array of all models matching a wildcard trigger" do
      models = Backup::Model.find_by_trigger("trigger_t*")
      expect(models.count).to be(2)
      expect(models[0].label).to eq("label2")
      expect(models[1].label).to eq("label3")

      models = Backup::Model.find_by_trigger("trig*ne")
      expect(models.count).to be(2)
      expect(models[0].label).to eq("label1")
      expect(models[1].label).to eq("label4")

      expect(Backup::Model.find_by_trigger("trigg*").count).to be(4)
    end

    it "should accept a symbol" do
      models = Backup::Model.find_by_trigger(:trigger_two)
      expect(models.count).to be(1)
      expect(models[0].label).to eq("label2")
    end

    it "should return an empty array if no matches are found" do
      expect(Backup::Model.find_by_trigger("foo*")).to eq([])
    end
  end # describe '.find_by_trigger'

  describe ".preconfigure" do
    it "returns preconfiguration block if set" do
      block = proc {}
      expect(Backup::Model.preconfigure).to be_nil
      Backup::Model.preconfigure(&block)
      expect(Backup::Model.preconfigure).to be(block)
    end

    it "stores preconfiguration for each subclass" do
      klass_a = Class.new(Backup::Model)
      klass_b = Class.new(Backup::Model)
      block_a = proc {}
      block_b = proc {}
      klass_a.preconfigure(&block_a)
      klass_b.preconfigure(&block_b)
      expect(klass_a.preconfigure).to be(block_a)
      expect(klass_b.preconfigure).to be(block_b)
    end
  end

  describe "subclassing Model" do
    specify "custom model triggers can be found" do
      klass = Class.new(Backup::Model)
      model_a = klass.new(:model_a, "Model A")
      model_b = Backup::Model.new(:model_b, "Mowel B")
      model_c = klass.new(:model_c, "Model C")
      expect(Backup::Model.all).to eq([model_a, model_b, model_c])
      expect(Backup::Model.find_by_trigger(:model_c).first).to be(model_c)
    end
  end

  describe "#initialize" do
    it "sets default values" do
      expect(model.trigger).to eq("test_trigger")
      expect(model.label).to eq("test label")
      expect(model.package).to be_an_instance_of Backup::Package
      expect(model.time).to be_nil

      expect(model.databases).to eq([])
      expect(model.archives).to eq([])
      expect(model.storages).to eq([])
      expect(model.notifiers).to eq([])
      expect(model.syncers).to eq([])

      expect(model.compressor).to be_nil
      expect(model.encryptor).to be_nil
      expect(model.splitter).to be_nil

      expect(model.exit_status).to be_nil
      expect(model.exception).to be_nil
    end

    it "should convert trigger to a string" do
      expect(Backup::Model.new(:foo, :bar).trigger).to eq("foo")
    end

    it "should convert label to a string" do
      expect(Backup::Model.new(:foo, :bar).label).to eq("bar")
    end

    it "should accept and instance_eval a block" do
      before_block = proc {}
      block = proc do
        before(&before_block)
      end
      model = Backup::Model.new(:foo, "", &block)
      expect(model.before).to be(before_block)
    end

    it "should instance_eval the preconfiguration block" do
      model_config_block  = ->(_) { throw(:block_called, :model_config) }
      pre_config_block    = ->(_) { throw(:block_called, :pre_config) }
      caught = catch(:block_called) do
        Backup::Model.preconfigure(&pre_config_block)
        Backup::Model.new("foo", "", &model_config_block)
      end
      expect(caught).to eq(:pre_config)
    end

    it "should add itself to Model.all" do
      expect(Backup::Model.all).to eq([model])
    end

    # see also: spec/support/shared_examples/database.rb
    it "triggers each database to generate it's #dump_filename" do
      db1 = mock
      db2 = mock
      db1.expects(:dump_filename)
      db2.expects(:dump_filename)
      Backup::Model.new(:test_trigger, "test label") do
        databases << db1
        databases << db2
      end
    end
  end # describe '#initialize'

  describe "DSL Methods" do
    module Fake
      module NoArg
        class Base
          attr_accessor :block_arg
          def initialize(&block)
            instance_eval(&block) if block_given?
          end
        end
      end
      module OneArg
        class Base
          attr_accessor :arg1, :block_arg
          def initialize(arg1, &block)
            @arg1 = arg1
            instance_eval(&block) if block_given?
          end
        end
      end
      module TwoArgs
        class Base
          attr_accessor :arg1, :arg2, :block_arg
          def initialize(arg1, arg2, &block)
            @arg1 = arg1
            @arg2 = arg2
            instance_eval(&block) if block_given?
          end
        end
      end
      module ThreeArgs
        class Base
          attr_accessor :arg1, :arg2, :arg3, :block_arg
          def initialize(arg1, arg2, arg3, &block)
            @arg1 = arg1
            @arg2 = arg2
            @arg3 = arg3
            instance_eval(&block) if block_given?
          end
        end
      end
    end

    # Set +const+ to +replacement+ for the calling block
    def using_fake(const, replacement)
      orig = Backup.const_get(const)
      Backup.send(:remove_const, const)
      Backup.const_set(const, replacement)
      yield
      Backup.send(:remove_const, const)
      Backup.const_set(const, orig)
    end

    describe "#archive" do
      it "should add archives" do
        using_fake("Archive", Fake::TwoArgs::Base) do
          model.archive("foo") { |a| a.block_arg = :foo }
          model.archive("bar") { |a| a.block_arg = :bar }
          expect(model.archives.count).to eq(2)
          a1, a2 = model.archives
          expect(a1.arg1).to be(model)
          expect(a1.arg2).to eq("foo")
          expect(a1.block_arg).to eq(:foo)
          expect(a2.arg1).to be(model)
          expect(a2.arg2).to eq("bar")
          expect(a2.block_arg).to eq(:bar)
        end
      end
    end

    describe "#database" do
      it "should add databases" do
        using_fake("Database", Fake::TwoArgs) do
          model.database("Base", "foo") { |a| a.block_arg = :foo }
          # second arg is optional
          model.database("Base") { |a| a.block_arg = :bar }
          expect(model.databases.count).to be(2)
          d1, d2 = model.databases
          expect(d1.arg1).to be(model)
          expect(d1.arg2).to eq("foo")
          expect(d1.block_arg).to eq(:foo)
          expect(d2.arg1).to be(model)
          expect(d2.arg2).to be_nil
          expect(d2.block_arg).to eq(:bar)
        end
      end

      it "should accept a nested class name" do
        using_fake("Database", Fake) do
          model.database("TwoArgs::Base")
          expect(model.databases.first).to be_an_instance_of Fake::TwoArgs::Base
        end
      end
    end

    describe "#store_with" do
      it "should add storages" do
        using_fake("Storage", Fake::TwoArgs) do
          model.store_with("Base", "foo") { |a| a.block_arg = :foo }
          # second arg is optional
          model.store_with("Base") { |a| a.block_arg = :bar }
          expect(model.storages.count).to be(2)
          s1, s2 = model.storages
          expect(s1.arg1).to be(model)
          expect(s1.arg2).to eq("foo")
          expect(s1.block_arg).to eq(:foo)
          expect(s2.arg1).to be(model)
          expect(s2.arg2).to be_nil
          expect(s2.block_arg).to eq(:bar)
        end
      end

      it "should accept a nested class name" do
        using_fake("Storage", Fake) do
          model.store_with("TwoArgs::Base")
          expect(model.storages.first).to be_an_instance_of Fake::TwoArgs::Base
        end
      end
    end

    describe "#sync_with" do
      it "should add syncers" do
        using_fake("Syncer", Fake::OneArg) do
          model.sync_with("Base", "foo") { |a| a.block_arg = :foo }
          # second arg is optional
          model.sync_with("Base") { |a| a.block_arg = :bar }
          expect(model.syncers.count).to be(2)
          s1, s2 = model.syncers
          expect(s1.arg1).to eq("foo")
          expect(s1.block_arg).to eq(:foo)
          expect(s2.arg1).to be_nil
          expect(s2.block_arg).to eq(:bar)
        end
      end

      it "should accept a nested class name" do
        using_fake("Syncer", Fake) do
          model.sync_with("OneArg::Base")
          expect(model.syncers.first).to be_an_instance_of Fake::OneArg::Base
        end
      end
    end

    describe "#notify_by" do
      it "should add notifiers" do
        using_fake("Notifier", Fake::OneArg) do
          model.notify_by("Base") { |a| a.block_arg = :foo }
          model.notify_by("Base") { |a| a.block_arg = :bar }
          expect(model.notifiers.count).to be(2)
          n1, n2 = model.notifiers
          expect(n1.arg1).to be(model)
          expect(n1.block_arg).to eq(:foo)
          expect(n2.arg1).to be(model)
          expect(n2.block_arg).to eq(:bar)
        end
      end

      it "should accept a nested class name" do
        using_fake("Notifier", Fake) do
          model.notify_by("OneArg::Base")
          expect(model.notifiers.first).to be_an_instance_of Fake::OneArg::Base
        end
      end
    end

    describe "#encrypt_with" do
      it "should add an encryptor" do
        using_fake("Encryptor", Fake::NoArg) do
          model.encrypt_with("Base") { |a| a.block_arg = :foo }
          expect(model.encryptor).to be_an_instance_of Fake::NoArg::Base
          expect(model.encryptor.block_arg).to eq(:foo)
        end
      end

      it "should accept a nested class name" do
        using_fake("Encryptor", Fake) do
          model.encrypt_with("NoArg::Base")
          expect(model.encryptor).to be_an_instance_of Fake::NoArg::Base
        end
      end
    end

    describe "#compress_with" do
      it "should add a compressor" do
        using_fake("Compressor", Fake::NoArg) do
          model.compress_with("Base") { |a| a.block_arg = :foo }
          expect(model.compressor).to be_an_instance_of Fake::NoArg::Base
          expect(model.compressor.block_arg).to eq(:foo)
        end
      end

      it "should accept a nested class name" do
        using_fake("Compressor", Fake) do
          model.compress_with("NoArg::Base")
          expect(model.compressor).to be_an_instance_of Fake::NoArg::Base
        end
      end
    end

    describe "#split_into_chunks_of" do
      it "should add a splitter" do
        using_fake("Splitter", Fake::ThreeArgs::Base) do
          model.split_into_chunks_of(123, 2)
          expect(model.splitter).to be_an_instance_of Fake::ThreeArgs::Base
          expect(model.splitter.arg1).to be(model)
          expect(model.splitter.arg2).to eq(123)
          expect(model.splitter.arg3).to eq(2)
        end
      end

      it "should raise an error if chunk_size is not an Integer" do
        expect do
          model.split_into_chunks_of("345", 2)
        end.to raise_error Backup::Model::Error, /must be Integers/
      end

      it "should raise an error if suffix_size is not an Integer" do
        expect do
          model.split_into_chunks_of(345, "2")
        end.to raise_error Backup::Model::Error, /must be Integers/
      end
    end
  end # describe 'DSL Methods'

  describe "#perform!" do
    let(:procedure_a)   { -> {} }
    let(:procedure_b)   { mock }
    let(:procedure_c)   { mock }
    let(:syncer_a)      { mock }
    let(:syncer_b)      { mock }

    it "sets started_at, time, package.time and finished_at" do
      Timecop.freeze
      started_at = Time.now.utc
      time = started_at.strftime("%Y.%m.%d.%H.%M.%S")
      finished_at = started_at + 5
      model.before { Timecop.freeze(finished_at) }
      model.perform!
      Timecop.return

      expect(model.started_at).to eq(started_at)
      expect(model.time).to eq(time)
      expect(model.package.time).to eq(time)
      expect(model.finished_at).to eq(finished_at)
    end

    it "performs all procedures" do
      model.stubs(:procedures).returns([procedure_a, [procedure_b, procedure_c]])
      model.stubs(:syncers).returns([syncer_a, syncer_b])

      model.expects(:log!).in_sequence(s).with(:started)

      procedure_a.expects(:call).in_sequence(s)
      procedure_b.expects(:perform!).in_sequence(s)
      procedure_c.expects(:perform!).in_sequence(s)

      syncer_a.expects(:perform!).in_sequence(s)
      syncer_b.expects(:perform!).in_sequence(s)

      model.expects(:log!).in_sequence(s).with(:finished)

      model.perform!

      expect(model.exception).to be_nil
      expect(model.exit_status).to be 0
    end

    describe "exit status" do
      it "sets exit_status to 0 when successful" do
        model.perform!

        expect(model.exception).to be_nil
        expect(model.exit_status).to be 0
      end

      it "sets exit_status to 1 when warnings are logged" do
        model.stubs(:procedures).returns([-> { Backup::Logger.warn "foo" }])

        model.perform!

        expect(model.exception).to be_nil
        expect(model.exit_status).to be 1
      end

      it "sets exit_status 2 for a StandardError" do
        err = StandardError.new "non-fatal error"
        model.stubs(:procedures).returns([-> { raise err }])

        model.perform!

        expect(model.exception).to eq(err)
        expect(model.exit_status).to be 2
      end

      it "sets exit_status 3 for an Exception" do
        err = Exception.new "fatal error"
        model.stubs(:procedures).returns([-> { raise err }])

        model.perform!

        expect(model.exception).to eq(err)
        expect(model.exit_status).to be 3
      end
    end # context 'when errors occur'

    describe "before/after hooks" do
      specify "both are called" do
        before_called = nil
        procedure_called = nil
        after_called_with = nil
        model.before { before_called = true }
        model.stubs(:procedures).returns([-> { procedure_called = true }])
        model.after { |status| after_called_with = status }

        model.perform!

        expect(before_called).to be_truthy
        expect(procedure_called).to be_truthy
        expect(after_called_with).to be 0
      end

      specify "before hook may log warnings" do
        procedure_called = nil
        after_called_with = nil
        model.before { Backup::Logger.warn "foo" }
        model.stubs(:procedures).returns([-> { procedure_called = true }])
        model.after { |status| after_called_with = status }

        model.perform!

        expect(model.exit_status).to be 1
        expect(procedure_called).to be_truthy
        expect(after_called_with).to be 1
      end

      specify "before hook may abort model with non-fatal exception" do
        procedure_called = false
        after_called = false
        model.before { raise StandardError }
        model.stubs(:procedures).returns([-> { procedure_called = true }])
        model.after { after_called = true }

        model.perform!

        expect(model.exit_status).to be 2
        expect(procedure_called).to eq(false)
        expect(after_called).to eq(false)
      end

      specify "before hook may abort backup with fatal exception" do
        procedure_called = false
        after_called = false
        model.before { raise Exception }
        model.stubs(:procedures).returns([-> { procedure_called = true }])
        model.after { after_called = true }

        model.perform!

        expect(model.exit_status).to be 3
        expect(procedure_called).to eq(false)
        expect(after_called).to eq(false)
      end

      specify "after hook is called when procedure raises non-fatal exception" do
        after_called_with = nil
        model.stubs(:procedures).returns([-> { raise StandardError }])
        model.after { |status| after_called_with = status }

        model.perform!

        expect(model.exit_status).to be 2
        expect(after_called_with).to be 2
      end

      specify "after hook is called when procedure raises fatal exception" do
        after_called_with = nil
        model.stubs(:procedures).returns([-> { raise Exception }])
        model.after { |status| after_called_with = status }

        model.perform!

        expect(model.exit_status).to be 3
        expect(after_called_with).to be 3
      end

      specify "after hook may log warnings" do
        after_called_with = nil
        model.after do |status|
          after_called_with = status
          Backup::Logger.warn "foo"
        end

        model.perform!

        expect(model.exit_status).to be 1
        expect(after_called_with).to be 0
      end

      specify "after hook warnings will not decrease exit_status" do
        after_called_with = nil
        model.stubs(:procedures).returns([-> { raise StandardError }])
        model.after do |status|
          after_called_with = status
          Backup::Logger.warn "foo"
        end

        model.perform!

        expect(model.exit_status).to be 2
        expect(after_called_with).to be 2
        expect(Backup::Logger.has_warnings?).to be_truthy
      end

      specify "after hook may fail model with non-fatal exceptions" do
        after_called_with = nil
        model.stubs(:procedures).returns([-> { Backup::Logger.warn "foo" }])
        model.after do |status|
          after_called_with = status
          raise StandardError
        end

        model.perform!

        expect(model.exit_status).to be 2
        expect(after_called_with).to be 1
      end

      specify "after hook exception will not decrease exit_status" do
        after_called_with = nil
        model.stubs(:procedures).returns([-> { raise Exception }])
        model.after do |status|
          after_called_with = status
          raise StandardError
        end

        model.perform!

        expect(model.exit_status).to be 3
        expect(after_called_with).to be 3
      end

      specify "after hook may abort backup with fatal exceptions" do
        after_called_with = nil
        model.stubs(:procedures).returns([-> { raise StandardError }])
        model.after do |status|
          after_called_with = status
          raise Exception
        end

        model.perform!

        expect(model.exit_status).to be 3
        expect(after_called_with).to be 2
      end

      specify "hooks may be overridden" do
        block_a = proc {}
        block_b = proc {}
        model.before(&block_a)
        expect(model.before).to be(block_a)
        model.before(&block_b)
        expect(model.before).to be(block_b)
      end
    end # describe 'hooks'
  end # describe '#perform!'

  describe "#duration" do
    it "returns a string representing the elapsed time" do
      Timecop.freeze do
        model.stubs(:finished_at).returns(Time.now)
        { 0       => "00:00:00", 1       => "00:00:01", 59      => "00:00:59",
          60      => "00:01:00", 61      => "00:01:01", 119     => "00:01:59",
          3540    => "00:59:00", 3541    => "00:59:01", 3599    => "00:59:59",
          3600    => "01:00:00", 3601    => "01:00:01", 3659    => "01:00:59",
          3660    => "01:01:00", 3661    => "01:01:01", 3719    => "01:01:59",
          7140    => "01:59:00", 7141    => "01:59:01", 7199    => "01:59:59",
          212_400  => "59:00:00", 212_401  => "59:00:01", 212_459  => "59:00:59",
          212_460  => "59:01:00", 212_461  => "59:01:01", 212_519  => "59:01:59",
          215_940  => "59:59:00", 215_941  => "59:59:01", 215_999  => "59:59:59" }.each do |duration, expected|
          model.stubs(:started_at).returns(Time.now - duration)
          expect(model.duration).to eq(expected)
        end
      end
    end

    it "returns nil if job has not finished" do
      model.stubs(:started_at).returns(Time.now)
      expect(model.duration).to be_nil
    end
  end # describe '#duration'

  describe "#procedures" do
    before do
      model.stubs(:prepare!).returns(:prepare)
      model.stubs(:package!).returns(:package)
      model.stubs(:store!).returns([:storage])
      model.stubs(:clean!).returns(:clean)
    end

    context "when no databases or archives are configured" do
      it "returns an empty array" do
        expect(model.send(:procedures)).to eq([])
      end
    end

    context "when databases are configured" do
      before do
        model.stubs(:databases).returns([:database])
      end

      it "returns all procedures" do
        one, two, three, four, five, six = model.send(:procedures)
        expect(one.call).to eq(:prepare)
        expect(two).to eq([:database])
        expect(three).to eq([])
        expect(four.call).to eq(:package)
        expect(five.call).to eq([:storage])
        expect(six.call).to eq(:clean)
      end
    end

    context "when archives are configured" do
      before do
        model.stubs(:archives).returns([:archive])
      end

      it "returns all procedures" do
        one, two, three, four, five, six = model.send(:procedures)
        expect(one.call).to eq(:prepare)
        expect(two).to eq([])
        expect(three).to eq([:archive])
        expect(four.call).to eq(:package)
        expect(five.call).to eq([:storage])
        expect(six.call).to eq(:clean)
      end
    end
  end # describe '#procedures'

  describe "#prepare!" do
    it "should prepare for the backup" do
      Backup::Cleaner.expects(:prepare).with(model)

      model.send(:prepare!)
    end
  end

  describe "#package!" do
    it "should package the backup" do
      Backup::Packager.expects(:package!).in_sequence(s).with(model)
      Backup::Cleaner.expects(:remove_packaging).in_sequence(s).with(model)

      model.send(:package!)
    end
  end

  describe "#store!" do
    context "when no storages are configured" do
      before do
        model.stubs(:storages).returns([])
      end

      it "should return true" do
        expect(model.send(:store!)).to eq true
      end
    end

    context "when multiple storages are configured" do
      let(:storage_one) { mock }
      let(:storage_two) { mock }

      before do
        model.stubs(:storages).returns([storage_one, storage_two])
      end

      it "should call storages in sequence and return true if all succeed" do
        storage_one.expects(:perform!).in_sequence(s).returns(true)
        storage_two.expects(:perform!).in_sequence(s).returns(true)

        expect(model.send(:store!)).to eq true
      end

      it "should call storages in sequence and re-raise the first exception that occours" do
        storage_one.expects(:perform!).in_sequence(s).raises "Storage error"
        storage_two.expects(:perform!).in_sequence(s).returns(true)

        expect { model.send(:store!) }.to raise_error StandardError, "Storage error"
      end

      context "and multiple storages fail" do
        let(:storage_three) { mock }

        before do
          model.stubs(:storages).returns([storage_one, storage_two, storage_three])
        end

        it "should log the exceptions that are not re-raised" do
          storage_one.expects(:perform!).raises "Storage error"
          storage_two.expects(:perform!).raises "Different error"
          storage_three.expects(:perform!).raises "Another error"

          expected_messages = [/\ADifferent error\z/, /.*/, /\AAnother error\z/, /.*/] # every other invocation contains a stack trace

          Backup::Logger.expects(:error).in_sequence(s).times(4).with do |err|
            err.to_s =~ expected_messages.shift
          end

          expect { model.send(:store!) }.to raise_error StandardError, "Storage error"
        end
      end
    end
  end

  describe "#clean!" do
    it "should remove the final packaged files" do
      Backup::Cleaner.expects(:remove_package).with(model.package)

      model.send(:clean!)
    end
  end

  describe "#get_class_from_scope" do
    module Fake
      module TestScope
        class TestKlass; end
      end
    end
    module TestScope
      module TestKlass; end
    end

    context "when name is given as a string" do
      it "should return the constant for the given scope and name" do
        result = model.send(:get_class_from_scope, Fake, "TestScope")
        expect(result).to eq(Fake::TestScope)
      end

      it "should accept a nested class name" do
        result = model.send(:get_class_from_scope, Fake, "TestScope::TestKlass")
        expect(result).to eq(Fake::TestScope::TestKlass)
      end
    end

    context "when name is given as a module" do
      it "should return the constant for the given scope and name" do
        result = model.send(:get_class_from_scope, Fake, TestScope)
        expect(result).to eq(Fake::TestScope)
      end

      it "should accept a nested class name" do
        result = model.send(:get_class_from_scope, Fake, TestScope::TestKlass)
        expect(result).to eq(Fake::TestScope::TestKlass)
      end
    end

    context "when name is given as a module defined under Backup::Config::DSL" do
      # this is necessary since the specs in spec/config/dsl_spec.rb
      # remove all the constants from Backup::Config::DSL as part of those tests.
      before(:context) do
        class Backup::Config::DSL
          module TestScope
            module TestKlass; end
          end
        end
      end

      it "should return the constant for the given scope and name" do
        result = model.send(
          :get_class_from_scope,
          Fake,
          Backup::Config::DSL::TestScope
        )
        expect(result).to eq(Fake::TestScope)
      end

      it "should accept a nested class name" do
        result = model.send(
          :get_class_from_scope,
          Fake,
          Backup::Config::DSL::TestScope::TestKlass
        )
        expect(result).to eq(Fake::TestScope::TestKlass)
      end
    end
  end # describe '#get_class_from_scope'

  describe "#set_exit_status" do
    context "when the model completed successfully without warnings" do
      it "sets exit status to 0" do
        model.send(:set_exit_status)
        expect(model.exit_status).to be(0)
      end
    end

    context "when the model completed successfully with warnings" do
      before { Backup::Logger.stubs(:has_warnings?).returns(true) }

      it "sets exit status to 1" do
        model.send(:set_exit_status)
        expect(model.exit_status).to be(1)
      end
    end

    context "when the model failed with a non-fatal exception" do
      before { model.stubs(:exception).returns(StandardError.new("non-fatal")) }

      it "sets exit status to 2" do
        model.send(:set_exit_status)
        expect(model.exit_status).to be(2)
      end
    end

    context "when the model failed with a fatal exception" do
      before { model.stubs(:exception).returns(Exception.new("fatal")) }

      it "sets exit status to 3" do
        model.send(:set_exit_status)
        expect(model.exit_status).to be(3)
      end
    end
  end # describe '#set_exit_status'

  describe "#log!" do
    context "when action is :started" do
      it "logs that the backup has started" do
        Backup::Logger.expects(:info).with(
          "Performing Backup for 'test label (test_trigger)'!\n" \
          "[ backup #{Backup::VERSION} : #{RUBY_DESCRIPTION} ]"
        )
        model.send(:log!, :started)
      end
    end

    context "when action is :finished" do
      before { model.stubs(:duration).returns("01:02:03") }

      context "when #exit_status is 0" do
        before { model.stubs(:exit_status).returns(0) }

        it "logs that the backup completed successfully" do
          Backup::Logger.expects(:info).with(
            "Backup for 'test label (test_trigger)' " \
            "Completed Successfully in 01:02:03"
          )
          model.send(:log!, :finished)
        end
      end

      context "when #exit_status is 1" do
        before { model.stubs(:exit_status).returns(1) }

        it "logs that the backup completed successfully with warnings" do
          Backup::Logger.expects(:warn).with(
            "Backup for 'test label (test_trigger)' " \
            "Completed Successfully (with Warnings) in 01:02:03"
          )
          model.send(:log!, :finished)
        end
      end

      context "when #exit_status is 2" do
        let(:error_a) { mock }

        before do
          model.stubs(:exit_status).returns(2)
          model.stubs(:exception).returns(StandardError.new("non-fatal error"))
          error_a.stubs(:backtrace).returns(["many", "backtrace", "lines"])
        end

        it "logs that the backup failed with a non-fatal exception" do
          Backup::Model::Error.expects(:wrap).in_sequence(s).with do |err, msg|
            expect(err.message).to eq("non-fatal error")
            expect(msg).to match(/Backup for test label \(test_trigger\) Failed!/)
          end.returns(error_a)
          Backup::Logger.expects(:error).in_sequence(s).with(error_a)
          Backup::Logger.expects(:error).in_sequence(s).with(
            "\nBacktrace:\n\s\smany\n\s\sbacktrace\n\s\slines\n\n"
          )

          Backup::Cleaner.expects(:warnings).in_sequence(s).with(model)

          model.send(:log!, :finished)
        end
      end

      context "when #exit_status is 3" do
        let(:error_a) { mock }

        before do
          model.stubs(:exit_status).returns(3)
          model.stubs(:exception).returns(Exception.new("fatal error"))
          error_a.stubs(:backtrace).returns(["many", "backtrace", "lines"])
        end

        it "logs that the backup failed with a fatal exception" do
          Backup::Model::FatalError.expects(:wrap).in_sequence(s).with do |err, msg|
            expect(err.message).to eq("fatal error")
            expect(msg).to match(/Backup for test label \(test_trigger\) Failed!/)
          end.returns(error_a)
          Backup::Logger.expects(:error).in_sequence(s).with(error_a)
          Backup::Logger.expects(:error).in_sequence(s).with(
            "\nBacktrace:\n\s\smany\n\s\sbacktrace\n\s\slines\n\n"
          )

          Backup::Cleaner.expects(:warnings).in_sequence(s).with(model)

          model.send(:log!, :finished)
        end
      end
    end
  end # describe '#log!'
end
