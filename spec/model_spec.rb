# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe 'Backup::Model' do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:s)     { sequence '' }

  before do
    Backup::Model.send(:reset!)
  end
  after do
    Backup::Model.send(:reset!)
  end

  describe '.all' do
    it 'should be an empty array by default' do
      Backup::Model.all.should == []
    end
  end

  describe '.find_by_trigger' do
    before do
      [:one, :two, :three, :one].each_with_index do |sym, i|
        Backup::Model.new("trigger_#{ sym }", "label#{ i + 1 }")
      end
    end

    it 'should return an array of all models matching the trigger' do
      models = Backup::Model.find_by_trigger('trigger_one')
      models.should be_a(Array)
      models.count.should be(2)
      models[0].label.should == 'label1'
      models[1].label.should == 'label4'
    end

    it 'should return an array of all models matching a wildcard trigger' do
      models = Backup::Model.find_by_trigger('trigger_t*')
      models.count.should be(2)
      models[0].label.should == 'label2'
      models[1].label.should == 'label3'

      models = Backup::Model.find_by_trigger('trig*ne')
      models.count.should be(2)
      models[0].label.should == 'label1'
      models[1].label.should == 'label4'

      Backup::Model.find_by_trigger('trigg*').count.should be(4)
    end

    it 'should accept a symbol' do
      models = Backup::Model.find_by_trigger(:trigger_two)
      models.count.should be(1)
      models[0].label.should == 'label2'
    end

    it 'should return an empty array if no matches are found' do
      Backup::Model.find_by_trigger('foo*').should == []
    end

  end # describe '.find_by_trigger'

  describe '.preconfigure' do

    it 'returns preconfiguration block if set' do
      block = Proc.new {}
      Backup::Model.preconfigure.should be_nil
      Backup::Model.preconfigure(&block)
      Backup::Model.preconfigure.should be(block)
    end

    it 'stores preconfiguration for each subclass' do
      klass_a, klass_b = Class.new(Backup::Model), Class.new(Backup::Model)
      block_a, block_b = Proc.new {}, Proc.new{}
      klass_a.preconfigure(&block_a)
      klass_b.preconfigure(&block_b)
      klass_a.preconfigure.should be(block_a)
      klass_b.preconfigure.should be(block_b)
    end
  end

  describe 'subclassing Model' do
    specify 'custom model triggers can be found' do
      klass = Class.new(Backup::Model)
      model_a = klass.new(:model_a, 'Model A')
      model_b = Backup::Model.new(:model_b, 'Mowel B')
      model_c = klass.new(:model_c, 'Model C')
      Backup::Model.all.should == [model_a, model_b, model_c]
      Backup::Model.find_by_trigger(:model_c).first.should be(model_c)
    end
  end

  describe '#initialize' do

    it 'sets default values' do
      model.trigger.should == 'test_trigger'
      model.label.should == 'test label'
      model.package.should be_an_instance_of Backup::Package
      model.time.should be_nil

      model.databases.should == []
      model.archives.should == []
      model.storages.should == []
      model.notifiers.should == []
      model.syncers.should == []

      model.compressor.should be_nil
      model.encryptor.should be_nil
      model.splitter.should be_nil

      model.exit_status.should be_nil
      model.exception.should be_nil
    end

    it 'should convert trigger to a string' do
      Backup::Model.new(:foo, :bar).trigger.should == 'foo'
    end

    it 'should convert label to a string' do
      Backup::Model.new(:foo, :bar).label.should == 'bar'
    end

    it 'should accept and instance_eval a block' do
      before_block = Proc.new {}
      block = Proc.new do
        before(&before_block)
      end
      model = Backup::Model.new(:foo, '', &block)
      model.before.should be(before_block)
    end

    it 'should instance_eval the preconfiguration block' do
      model_config_block  = lambda {|model| throw(:block_called, :model_config) }
      pre_config_block    = lambda {|model| throw(:block_called, :pre_config) }
      caught = catch(:block_called) do
        Backup::Model.preconfigure(&pre_config_block)
        Backup::Model.new('foo', '', &model_config_block)
      end
      caught.should == :pre_config
    end

    it 'should add itself to Model.all' do
      Backup::Model.all.should == [model]
    end

    # see also: spec/support/shared_examples/database.rb
    it "triggers each database to generate it's #dump_filename" do
      db1, db2 = mock, mock
      db1.expects(:dump_filename)
      db2.expects(:dump_filename)
      Backup::Model.new(:test_trigger, 'test label') do
        self.databases << db1
        self.databases << db2
      end
    end

  end # describe '#initialize'

  describe 'DSL Methods' do

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

    describe '#archive' do
      it 'should add archives' do
        using_fake('Archive', Fake::TwoArgs::Base) do
          model.archive('foo') {|a| a.block_arg = :foo }
          model.archive('bar') {|a| a.block_arg = :bar }
          model.archives.count.should == 2
          a1, a2 = model.archives
          a1.arg1.should be(model)
          a1.arg2.should == 'foo'
          a1.block_arg.should == :foo
          a2.arg1.should be(model)
          a2.arg2.should == 'bar'
          a2.block_arg.should == :bar
        end
      end
    end

    describe '#database' do
      it 'should add databases' do
        using_fake('Database', Fake::TwoArgs) do
          model.database('Base', 'foo') {|a| a.block_arg = :foo }
          # second arg is optional
          model.database('Base') {|a| a.block_arg = :bar }
          model.databases.count.should be(2)
          d1, d2 = model.databases
          d1.arg1.should be(model)
          d1.arg2.should == 'foo'
          d1.block_arg.should == :foo
          d2.arg1.should be(model)
          d2.arg2.should be_nil
          d2.block_arg.should == :bar
        end
      end

      it 'should accept a nested class name' do
        using_fake('Database', Fake) do
          model.database('TwoArgs::Base')
          model.databases.first.should be_an_instance_of Fake::TwoArgs::Base
        end
      end
    end

    describe '#store_with' do
      it 'should add storages' do
        using_fake('Storage', Fake::TwoArgs) do
          model.store_with('Base', 'foo') {|a| a.block_arg = :foo }
          # second arg is optional
          model.store_with('Base') {|a| a.block_arg = :bar }
          model.storages.count.should be(2)
          s1, s2 = model.storages
          s1.arg1.should be(model)
          s1.arg2.should == 'foo'
          s1.block_arg.should == :foo
          s2.arg1.should be(model)
          s2.arg2.should be_nil
          s2.block_arg.should == :bar
        end
      end

      it 'should accept a nested class name' do
        using_fake('Storage', Fake) do
          model.store_with('TwoArgs::Base')
          model.storages.first.should be_an_instance_of Fake::TwoArgs::Base
        end
      end
    end

    describe '#sync_with' do
      it 'should add syncers' do
        using_fake('Syncer', Fake::OneArg) do
          model.sync_with('Base', 'foo') {|a| a.block_arg = :foo }
          # second arg is optional
          model.sync_with('Base') {|a| a.block_arg = :bar }
          model.syncers.count.should be(2)
          s1, s2 = model.syncers
          s1.arg1.should == 'foo'
          s1.block_arg.should == :foo
          s2.arg1.should be_nil
          s2.block_arg.should == :bar
        end
      end

      it 'should accept a nested class name' do
        using_fake('Syncer', Fake) do
          model.sync_with('OneArg::Base')
          model.syncers.first.should be_an_instance_of Fake::OneArg::Base
        end
      end

      it 'should warn user of change from RSync to RSync::Push' do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should match(
            "'sync_with RSync' is now 'sync_with RSync::Push'"
          )
        end
        model.expects(:get_class_from_scope).
            with(Backup::Syncer, 'RSync::Push').
            returns(stub(:new))
        model.sync_with('Backup::Config::RSync')
      end

      it 'should warn user of change from S3 to Cloud::S3' do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should match(
            "'sync_with S3' is now 'sync_with Cloud::S3'"
          )
        end
        model.expects(:get_class_from_scope).
            with(Backup::Syncer, 'Cloud::S3').
            returns(stub(:new))
        model.sync_with('Backup::Config::S3')
      end

      it 'should warn user of change from CloudFiles to Cloud::CloudFiles' do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should match(
            "'sync_with CloudFiles' is now 'sync_with Cloud::CloudFiles'"
          )
        end
        model.expects(:get_class_from_scope).
            with(Backup::Syncer, 'Cloud::CloudFiles').
            returns(stub(:new))
        model.sync_with('Backup::Config::CloudFiles')
      end
    end

    describe '#notify_by' do
      it 'should add notifiers' do
        using_fake('Notifier', Fake::OneArg) do
          model.notify_by('Base') {|a| a.block_arg = :foo }
          model.notify_by('Base') {|a| a.block_arg = :bar }
          model.notifiers.count.should be(2)
          n1, n2 = model.notifiers
          n1.arg1.should be(model)
          n1.block_arg.should == :foo
          n2.arg1.should be(model)
          n2.block_arg.should == :bar
        end
      end

      it 'should accept a nested class name' do
        using_fake('Notifier', Fake) do
          model.notify_by('OneArg::Base')
          model.notifiers.first.should be_an_instance_of Fake::OneArg::Base
        end
      end
    end

    describe '#encrypt_with' do
      it 'should add an encryptor' do
        using_fake('Encryptor', Fake::NoArg) do
          model.encrypt_with('Base') {|a| a.block_arg = :foo }
          model.encryptor.should be_an_instance_of Fake::NoArg::Base
          model.encryptor.block_arg.should == :foo
        end
      end

      it 'should accept a nested class name' do
        using_fake('Encryptor', Fake) do
          model.encrypt_with('NoArg::Base')
          model.encryptor.should be_an_instance_of Fake::NoArg::Base
        end
      end
    end

    describe '#compress_with' do
      it 'should add a compressor' do
        using_fake('Compressor', Fake::NoArg) do
          model.compress_with('Base') {|a| a.block_arg = :foo }
          model.compressor.should be_an_instance_of Fake::NoArg::Base
          model.compressor.block_arg.should == :foo
        end
      end

      it 'should accept a nested class name' do
        using_fake('Compressor', Fake) do
          model.compress_with('NoArg::Base')
          model.compressor.should be_an_instance_of Fake::NoArg::Base
        end
      end
    end

    describe '#split_into_chunks_of' do
      it 'should add a splitter' do
        using_fake('Splitter', Fake::ThreeArgs::Base) do
          model.split_into_chunks_of(123, 2)
          model.splitter.should be_an_instance_of Fake::ThreeArgs::Base
          model.splitter.arg1.should be(model)
          model.splitter.arg2.should == 123
          model.splitter.arg3.should == 2
        end
      end

      it 'should raise an error if chunk_size is not an Integer' do
        expect do
          model.split_into_chunks_of('345', 2)
        end.to raise_error {|err|
          err.should be_an_instance_of Backup::Model::Error
          err.message.should match(/must be Integers/)
        }
      end

      it 'should raise an error if suffix_size is not an Integer' do
        expect do
          model.split_into_chunks_of(345, '2')
        end.to raise_error {|err|
          err.should be_an_instance_of Backup::Model::Error
          err.message.should match(/must be Integers/)
        }
      end
    end

  end # describe 'DSL Methods'

  describe '#perform!' do
    let(:procedure_a)   { lambda {} }
    let(:procedure_b)   { mock }
    let(:procedure_c)   { mock }
    let(:syncer_a)      { mock }
    let(:syncer_b)      { mock }

    it 'sets started_at, time, package.time and finished_at' do
      Timecop.freeze
      started_at = Time.now.utc
      time = started_at.strftime("%Y.%m.%d.%H.%M.%S")
      finished_at = started_at + 5
      model.before { Timecop.freeze(finished_at) }
      model.perform!
      Timecop.return

      model.started_at.should == started_at
      model.time.should == time
      model.package.time.should == time
      model.finished_at.should == finished_at
    end

    it 'performs all procedures' do
      model.stubs(:procedures).returns([ procedure_a, [procedure_b, procedure_c]])
      model.stubs(:syncers).returns([syncer_a, syncer_b])

      model.expects(:log!).in_sequence(s).with(:started)

      procedure_a.expects(:call).in_sequence(s)
      procedure_b.expects(:perform!).in_sequence(s)
      procedure_c.expects(:perform!).in_sequence(s)

      syncer_a.expects(:perform!).in_sequence(s)
      syncer_b.expects(:perform!).in_sequence(s)

      model.expects(:log!).in_sequence(s).with(:finished)

      model.perform!

      model.exception.should be_nil
      model.exit_status.should be 0
    end

    describe 'exit status' do
      it 'sets exit_status to 0 when successful' do
        model.perform!

        model.exception.should be_nil
        model.exit_status.should be 0
      end

      it 'sets exit_status to 1 when warnings are logged' do
        model.stubs(:procedures).returns([lambda { Backup::Logger.warn 'foo' }])

        model.perform!

        model.exception.should be_nil
        model.exit_status.should be 1
      end

      it 'sets exit_status 2 for a StandardError' do
        err = StandardError.new 'non-fatal error'
        model.stubs(:procedures).returns([lambda { raise err }])

        model.perform!

        model.exception.should == err
        model.exit_status.should be 2
      end

      it 'sets exit_status 3 for an Exception' do
        err = Exception.new 'fatal error'
        model.stubs(:procedures).returns([lambda { raise err }])

        model.perform!

        model.exception.should == err
        model.exit_status.should be 3
      end
    end # context 'when errors occur'

    describe 'before/after hooks' do

      specify 'both are called' do
        before_called, procedure_called, after_called_with = nil, nil, nil
        model.before { before_called = true }
        model.stubs(:procedures).returns([lambda { procedure_called = true }])
        model.after {|status| after_called_with = status }

        model.perform!

        before_called.should be_true
        procedure_called.should be_true
        after_called_with.should be 0
      end

      specify 'before hook may log warnings' do
        procedure_called, after_called_with = nil, nil
        model.before { Backup::Logger.warn 'foo' }
        model.stubs(:procedures).returns([lambda { procedure_called = true }])
        model.after {|status| after_called_with = status }

        model.perform!

        model.exit_status.should be 1
        procedure_called.should be_true
        after_called_with.should be 1
      end

      specify 'before hook may abort model with non-fatal exception' do
        procedure_called, after_called = nil, nil
        model.before { raise StandardError }
        model.stubs(:procedures).returns([lambda { procedure_called = true }])
        model.after { after_called = true }

        model.perform!

        model.exit_status.should be 2
        procedure_called.should be_false
        after_called.should be_false
      end

      specify 'before hook may abort backup with fatal exception' do
        procedure_called, after_called = nil, nil
        model.before { raise Exception }
        model.stubs(:procedures).returns([lambda { procedure_called = true }])
        model.after { after_called = true }

        model.perform!

        model.exit_status.should be 3
        procedure_called.should be_false
        after_called.should be_false
      end

      specify 'after hook is called when procedure raises non-fatal exception' do
        after_called_with = nil
        model.stubs(:procedures).returns([lambda { raise StandardError }])
        model.after {|status| after_called_with = status }

        model.perform!

        model.exit_status.should be 2
        after_called_with.should be 2
      end

      specify 'after hook is called when procedure raises fatal exception' do
        after_called_with = nil
        model.stubs(:procedures).returns([lambda { raise Exception }])
        model.after {|status| after_called_with = status }

        model.perform!

        model.exit_status.should be 3
        after_called_with.should be 3
      end

      specify 'after hook may log warnings' do
        after_called_with = nil
        model.after {|status| after_called_with = status; Backup::Logger.warn 'foo' }

        model.perform!

        model.exit_status.should be 1
        after_called_with.should be 0
      end

      specify 'after hook warnings will not decrease exit_status' do
        after_called_with = nil
        model.stubs(:procedures).returns([lambda { raise StandardError }])
        model.after {|status| after_called_with = status; Backup::Logger.warn 'foo' }

        model.perform!

        model.exit_status.should be 2
        after_called_with.should be 2
        Backup::Logger.has_warnings?.should be_true
      end

      specify 'after hook may fail model with non-fatal exceptions' do
        after_called_with = nil
        model.stubs(:procedures).returns([lambda { Backup::Logger.warn 'foo' }])
        model.after {|status| after_called_with = status; raise StandardError }

        model.perform!

        model.exit_status.should be 2
        after_called_with.should be 1
      end

      specify 'after hook exception will not decrease exit_status' do
        after_called_with = nil
        model.stubs(:procedures).returns([lambda { raise Exception }])
        model.after {|status| after_called_with = status; raise StandardError }

        model.perform!

        model.exit_status.should be 3
        after_called_with.should be 3
      end

      specify 'after hook may abort backup with fatal exceptions' do
        after_called_with = nil
        model.stubs(:procedures).returns([lambda { raise StandardError }])
        model.after {|status| after_called_with = status; raise Exception }

        model.perform!

        model.exit_status.should be 3
        after_called_with.should be 2
      end

      specify 'hooks may be overridden' do
        block_a, block_b = Proc.new {}, Proc.new {}
        model.before(&block_a)
        model.before.should be(block_a)
        model.before(&block_b)
        model.before.should be(block_b)
      end

    end # describe 'hooks'

  end # describe '#perform!'

  describe '#duration' do
    it 'returns a string representing the elapsed time' do
      Timecop.freeze do
        model.stubs(:finished_at).returns(Time.now)
        { 0       => '00:00:00', 1       => '00:00:01', 59      => '00:00:59',
          60      => '00:01:00', 61      => '00:01:01', 119     => '00:01:59',
          3540    => '00:59:00', 3541    => '00:59:01', 3599    => '00:59:59',
          3600    => '01:00:00', 3601    => '01:00:01', 3659    => '01:00:59',
          3660    => '01:01:00', 3661    => '01:01:01', 3719    => '01:01:59',
          7140    => '01:59:00', 7141    => '01:59:01', 7199    => '01:59:59',
          212400  => '59:00:00', 212401  => '59:00:01', 212459  => '59:00:59',
          212460  => '59:01:00', 212461  => '59:01:01', 212519  => '59:01:59',
          215940  => '59:59:00', 215941  => '59:59:01', 215999  => '59:59:59'
        }.each do |duration, expected|
          model.stubs(:started_at).returns(Time.now - duration)
          model.duration.should == expected
        end
      end
    end

    it 'returns nil if job has not finished' do
      model.stubs(:started_at).returns(Time.now)
      model.duration.should be_nil
    end
  end # describe '#duration'

  describe '#procedures' do
    before do
      model.stubs(:prepare!).returns(:prepare)
      model.stubs(:package!).returns(:package)
      model.stubs(:storages).returns([:storage])
      model.stubs(:clean!).returns(:clean)
    end

    context 'when no databases or archives are configured' do
      it 'returns an empty array' do
        model.send(:procedures).should == []
      end
    end

    context 'when databases are configured' do
      before do
        model.stubs(:databases).returns([:database])
      end

      it 'returns all procedures' do
        one, two, three, four, five, six = model.send(:procedures)
        one.call.should == :prepare
        two.should == [:database]
        three.should == []
        four.call.should == :package
        five.should == [:storage]
        six.call.should == :clean
      end
    end

    context 'when archives are configured' do
      before do
        model.stubs(:archives).returns([:archive])
      end

      it 'returns all procedures' do
        one, two, three, four, five, six = model.send(:procedures)
        one.call.should == :prepare
        two.should == []
        three.should == [:archive]
        four.call.should == :package
        five.should == [:storage]
        six.call.should == :clean
      end
    end
  end # describe '#procedures'

  describe '#prepare!' do
    it 'should prepare for the backup' do
      Backup::Cleaner.expects(:prepare).with(model)

      model.send(:prepare!)
    end
  end

  describe '#package!' do
    it 'should package the backup' do
      Backup::Packager.expects(:package!).in_sequence(s).with(model)
      Backup::Cleaner.expects(:remove_packaging).in_sequence(s).with(model)

      model.send(:package!)
    end
  end

  describe '#clean!' do
    it 'should remove the final packaged files' do
      Backup::Cleaner.expects(:remove_package).with(model.package)

      model.send(:clean!)
    end
  end

  describe '#get_class_from_scope' do

    module Fake
      module TestScope
        class TestKlass; end
      end
    end
    module TestScope
      module TestKlass; end
    end

    context 'when name is given as a string' do
      it 'should return the constant for the given scope and name' do
        model.send(
          :get_class_from_scope,
          Fake,
          'TestScope'
        ).should == Fake::TestScope
      end

      it 'should accept a nested class name' do
        model.send(
          :get_class_from_scope,
          Fake,
          'TestScope::TestKlass'
        ).should == Fake::TestScope::TestKlass
      end
    end

    context 'when name is given as a module' do
      it 'should return the constant for the given scope and name' do
        model.send(
          :get_class_from_scope,
          Fake,
          TestScope
        ).should == Fake::TestScope
      end

      it 'should accept a nested class name' do
        model.send(
          :get_class_from_scope,
          Fake,
          TestScope::TestKlass
        ).should == Fake::TestScope::TestKlass
      end
    end

    context 'when name is given as a module defined under Backup::Config' do
      # this is necessary since the specs in spec/config_spec.rb
      # remove all the constants from Backup::Config as part of those tests.
      before(:all) do
        module Backup::Config
          module TestScope
            module TestKlass; end
          end
        end
      end

      it 'should return the constant for the given scope and name' do
        model.send(
          :get_class_from_scope,
          Fake,
          Backup::Config::TestScope
        ).should == Fake::TestScope
      end

      it 'should accept a nested class name' do
        model.send(
          :get_class_from_scope,
          Fake,
          Backup::Config::TestScope::TestKlass
        ).should == Fake::TestScope::TestKlass
      end
    end

  end # describe '#get_class_from_scope'

  describe '#set_exit_status' do
    context 'when the model completed successfully without warnings' do
      it 'sets exit status to 0' do
        model.send(:set_exit_status)
        model.exit_status.should be(0)
      end
    end

    context 'when the model completed successfully with warnings' do
      before { Backup::Logger.stubs(:has_warnings?).returns(true) }

      it 'sets exit status to 1' do
        model.send(:set_exit_status)
        model.exit_status.should be(1)
      end
    end

    context 'when the model failed with a non-fatal exception' do
      before { model.stubs(:exception).returns(StandardError.new 'non-fatal') }

      it 'sets exit status to 2' do
        model.send(:set_exit_status)
        model.exit_status.should be(2)
      end
    end

    context 'when the model failed with a fatal exception' do
      before { model.stubs(:exception).returns(Exception.new 'fatal') }

      it 'sets exit status to 3' do
        model.send(:set_exit_status)
        model.exit_status.should be(3)
      end
    end
  end # describe '#set_exit_status'

  describe '#log!' do
    context 'when action is :started' do
      it 'logs that the backup has started' do
        Backup::Logger.expects(:info).with(
          "Performing Backup for 'test label (test_trigger)'!\n" +
          "[ backup #{ Backup::VERSION } : #{ RUBY_DESCRIPTION } ]"
        )
        model.send(:log!, :started)
      end
    end

    context 'when action is :finished' do
      before { model.stubs(:duration).returns('01:02:03') }

      context 'when #exit_status is 0' do
        before { model.stubs(:exit_status).returns(0) }

        it 'logs that the backup completed successfully' do
          Backup::Logger.expects(:info).with(
            "Backup for 'test label (test_trigger)' " +
            "Completed Successfully in 01:02:03"
          )
          model.send(:log!, :finished)
        end
      end

      context 'when #exit_status is 1' do
        before { model.stubs(:exit_status).returns(1) }

        it 'logs that the backup completed successfully with warnings' do
          Backup::Logger.expects(:warn).with(
            "Backup for 'test label (test_trigger)' " +
            "Completed Successfully (with Warnings) in 01:02:03"
          )
          model.send(:log!, :finished)
        end
      end

      context 'when #exit_status is 2' do
        let(:error_a)   { mock }

        before do
          model.stubs(:exit_status).returns(2)
          model.stubs(:exception).returns(StandardError.new 'non-fatal error')
          error_a.stubs(:backtrace).returns(['many', 'backtrace', 'lines'])
        end

        it 'logs that the backup failed with a non-fatal exception' do
          Backup::Model::Error.expects(:wrap).in_sequence(s).with do |err, msg|
            err.message.should == 'non-fatal error'
            msg.should match(/Backup for test label \(test_trigger\) Failed!/)
          end.returns(error_a)
          Backup::Logger.expects(:error).in_sequence(s).with(error_a)
          Backup::Logger.expects(:error).in_sequence(s).with(
            "\nBacktrace:\n\s\smany\n\s\sbacktrace\n\s\slines\n\n"
          )

          Backup::Cleaner.expects(:warnings).in_sequence(s).with(model)

          model.send(:log!, :finished)
        end
      end

      context 'when #exit_status is 3' do
        let(:error_a)   { mock }

        before do
          model.stubs(:exit_status).returns(3)
          model.stubs(:exception).returns(Exception.new 'fatal error')
          error_a.stubs(:backtrace).returns(['many', 'backtrace', 'lines'])
        end

        it 'logs that the backup failed with a fatal exception' do
          Backup::Model::FatalError.expects(:wrap).in_sequence(s).with do |err, msg|
            err.message.should == 'fatal error'
            msg.should match(/Backup for test label \(test_trigger\) Failed!/)
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
