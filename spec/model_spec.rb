# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe 'Backup::Model' do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:s)     { sequence '' }

  before do
    Backup::Model.all.clear
  end

  describe '.all' do
    it 'should be an empty array by default' do
      Backup::Model.all.should == []
    end
  end

  describe 'finder methods' do
    before do
      [:a, :b, :c, :b, :d].each_with_index do |sym, i|
        Backup::Model.new("trigger_#{sym}", "label#{i}")
      end
    end

    describe '.find' do
      it 'should return the first matching model' do
        Backup::Model.find('trigger_b').label.should == 'label1'
      end

      it 'should accept symbols' do
        Backup::Model.find(:trigger_b).label.should == 'label1'
      end

      it 'should raise an error if trigger is not found' do
        expect do
          Backup::Model.find(:f)
        end.to raise_error(
          Backup::Errors::Model::MissingTriggerError,
          "Model::MissingTriggerError: Could not find trigger 'f'."
        )
      end
    end

    describe '.find_matching' do
      it 'should find all triggers matching a wildcard' do
        Backup::Model.find_matching('tri*_b').count.should be(2)
        Backup::Model.find_matching('trigg*').count.should be(5)
      end

      it 'should return an empty array if no matches are found' do
        Backup::Model.find_matching('foo*').should == []
      end
    end

  end # describe 'finder methods'

  describe '#initialize' do

    it 'should convert trigger to a string' do
      Backup::Model.new(:foo, :bar).trigger.should == 'foo'
    end

    it 'should convert label to a string' do
      Backup::Model.new(:foo, :bar).label.should == 'bar'
    end

    it 'should set all procedure variables to an empty array' do
      model.send(:procedure_instance_variables).each do |var|
        model.instance_variable_get(var).should == []
      end
    end

    it 'should accept and instance_eval a block' do
      block = lambda {|model| throw(:instance, model) }
      caught = catch(:instance) do
        Backup::Model.new('gotcha', '', &block)
      end
      caught.trigger.should == 'gotcha'
    end

    it 'should add itself to Model.all' do
      Backup::Model.all.should == [model]
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
        using_fake('Database', Fake::OneArg) do
          model.database('Base') {|a| a.block_arg = :foo }
          model.database('Base') {|a| a.block_arg = :bar }
          model.databases.count.should be(2)
          d1, d2 = model.databases
          d1.arg1.should be(model)
          d1.block_arg.should == :foo
          d2.arg1.should be(model)
          d2.block_arg.should == :bar
        end
      end

      it 'should accept a nested class name' do
        using_fake('Database', Fake) do
          model.database('OneArg::Base')
          model.databases.first.should be_an_instance_of Fake::OneArg::Base
        end
      end
    end

    describe '#store_with' do
      it 'should add storages' do
        using_fake('Storage', Fake::TwoArgs) do
          model.store_with('Base', 'foo') {|a| a.block_arg = :foo }
          model.store_with('Base', 'bar') {|a| a.block_arg = :bar }
          model.storages.count.should be(2)
          s1, s2 = model.storages
          s1.arg1.should be(model)
          s1.arg2.should == 'foo'
          s1.block_arg.should == :foo
          s2.arg1.should be(model)
          s2.arg2.should == 'bar'
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
        using_fake('Syncer', Fake::NoArg) do
          model.sync_with('Base') {|a| a.block_arg = :foo }
          model.sync_with('Base') {|a| a.block_arg = :bar }
          model.syncers.count.should be(2)
          s1, s2 = model.syncers
          s1.block_arg.should == :foo
          s2.block_arg.should == :bar
        end
      end

      it 'should accept a nested class name' do
        using_fake('Syncer', Fake) do
          model.sync_with('NoArg::Base')
          model.syncers.first.should be_an_instance_of Fake::NoArg::Base
        end
      end

      it 'should warn user of change from RSync to RSync::Push' do
        Backup::Logger.expects(:warn)
        model.sync_with('Backup::Config::RSync')
        model.syncers.first.should
            be_an_instance_of Backup::Syncer::RSync::Push
      end

      it 'should warn user of change from S3 to Cloud::S3' do
        Backup::Logger.expects(:warn)
        model.sync_with('Backup::Config::S3')
        model.syncers.first.should
            be_an_instance_of Backup::Syncer::Cloud::S3
      end

      it 'should warn user of change from CloudFiles to Cloud::CloudFiles' do
        Backup::Logger.expects(:warn)
        model.sync_with('Backup::Config::CloudFiles')
        model.syncers.first.should
            be_an_instance_of Backup::Syncer::Cloud::CloudFiles
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
        using_fake('Splitter', Fake::TwoArgs::Base) do
          model.split_into_chunks_of(123)
          model.splitter.should be_an_instance_of Fake::TwoArgs::Base
          model.splitter.arg1.should be(model)
          model.splitter.arg2.should == 123
        end
      end

      it 'should raise an error if chunk_size is not an Integer' do
        expect do
          model.split_into_chunks_of('345')
        end.to raise_error {|err|
          err.should be_an_instance_of Backup::Errors::Model::ConfigurationError
          err.message.should match(/must be an Integer/)
        }
      end
    end

    describe "hooks" do
      it "should add hooks" do
        model.hooks do
          before { a+=1 }
          after { b+=1 }
        end
        model.hooks.should be_an_instance_of Backup::Hooks
        model.hooks.after_proc.should be_an_instance_of Proc
        model.hooks.before_proc.should be_an_instance_of Proc
      end
    end

  end # describe 'DSL Methods'

  describe '#prepare!' do
    it 'should prepare for the backup' do
      FileUtils.expects(:mkdir_p).with(
        File.join(Backup::Config.data_path, 'test_trigger')
      )
      Backup::Cleaner.expects(:prepare).with(model)

      model.prepare!
    end
  end

  describe '#perform!' do
    let(:procedure_a)   { lambda {} }
    let(:procedure_b)   { mock }
    let(:procedure_c)   { mock }
    let(:procedure_d)   { lambda {} }
    let(:procedure_e)   { lambda {} }
    let(:procedure_f)   { mock }
    let(:procedures) do
      [ procedure_a, [procedure_b, procedure_c],
        procedure_d, procedure_e, [procedure_f] ]
    end
    let(:syncer_a)      { mock }
    let(:syncer_b)      { mock }
    let(:syncers)       { [syncer_a, syncer_b] }
    let(:notifier_a)    { mock }
    let(:notifier_b)    { mock }
    let(:notifiers)     { [notifier_a, notifier_b] }

    it 'should set the @time and @started_at variables' do
      Timecop.freeze(Time.now)
      started_at = Time.now
      time = started_at.strftime("%Y.%m.%d.%H.%M.%S")
      model.expects(:log!).with(:started)
      model.expects(:log!).with(:finished)

      model.perform!
      model.time.should == time
      model.instance_variable_get(:@started_at).should == started_at
    end

    it 'should call before and after hooks' do
      h = model.hooks
      h.expects(:perform!).with(:before)
      h.expects(:perform!).with(:after)

      model.expects(:log!).with(:started)
      model.expects(:log!).with(:finished)
      model.perform!
    end

    context 'when no errors occur' do
      before do
        model.expects(:procedures).returns(procedures)
        model.expects(:syncers).returns(syncers)
        model.expects(:notifiers).returns(notifiers)
      end

      context 'when databases are configured' do
        before do
          model.instance_variable_set(:@databases, [true])
        end

        it 'should perform all procedures' do
          model.expects(:log!).in_sequence(s).with(:started)

          procedure_a.expects(:call).in_sequence(s)
          procedure_b.expects(:perform!).in_sequence(s)
          procedure_c.expects(:perform!).in_sequence(s)
          procedure_d.expects(:call).in_sequence(s)
          procedure_e.expects(:call).in_sequence(s)
          procedure_f.expects(:perform!).in_sequence(s)

          syncer_a.expects(:perform!).in_sequence(s)
          syncer_b.expects(:perform!).in_sequence(s)

          notifier_a.expects(:perform!).in_sequence(s)
          notifier_b.expects(:perform!).in_sequence(s)

          model.expects(:log!).in_sequence(s).with(:finished)

          model.perform!
        end
      end

      context 'when archives are configured' do
        before do
          model.instance_variable_set(:@archives, [true])
        end

        it 'should perform all procedures' do
          model.expects(:log!).in_sequence(s).with(:started)

          procedure_a.expects(:call).in_sequence(s)
          procedure_b.expects(:perform!).in_sequence(s)
          procedure_c.expects(:perform!).in_sequence(s)
          procedure_d.expects(:call).in_sequence(s)
          procedure_e.expects(:call).in_sequence(s)
          procedure_f.expects(:perform!).in_sequence(s)

          syncer_a.expects(:perform!).in_sequence(s)
          syncer_b.expects(:perform!).in_sequence(s)

          notifier_a.expects(:perform!).in_sequence(s)
          notifier_b.expects(:perform!).in_sequence(s)

          model.expects(:log!).in_sequence(s).with(:finished)

          model.perform!
        end
      end

    end # context 'when no errors occur'

    # for the purposes of testing the error handling, we're just going to
    # stub the first thing this method calls and raise an error
    context 'when errors occur' do
      let(:error_a)   { mock }
      let(:error_b)   { mock }
      let(:notifier)  { mock }

      before do
        error_a.stubs(:backtrace).returns(['many', 'backtrace', 'lines'])
      end

      it 'logs, notifies and continues if a StandardError is rescued' do
        Time.stubs(:now).raises(StandardError, 'non-fatal error')

        Backup::Errors::ModelError.expects(:wrap).in_sequence(s).with do |err, msg|
          err.message.should == 'non-fatal error'
          msg.should match(/Backup for test label \(test_trigger\) Failed!/)
        end.returns(error_a)
        Backup::Logger.expects(:error).in_sequence(s).with(error_a)
        Backup::Logger.expects(:error).in_sequence(s).with(
          "\nBacktrace:\n\s\smany\n\s\sbacktrace\n\s\slines\n\n"
        )

        Backup::Cleaner.expects(:warnings).in_sequence(s).with(model)

        Backup::Errors::ModelError.expects(:new).in_sequence(s).with do |msg|
          msg.should match(/Backup will now attempt to continue/)
        end.returns(error_b)
        Backup::Logger.expects(:message).in_sequence(s).with(error_b)

        # notifiers called, but any Exception is ignored
        notifier.expects(:perform!).with(true).raises(Exception)
        model.expects(:notifiers).returns([notifier])

        # returns to allow next trigger to run
        expect { model.perform! }.not_to raise_error
      end

      it 'logs, notifies and exits if an Exception is rescued' do
        Time.stubs(:now).raises(Exception, 'fatal error')

        Backup::Errors::ModelError.expects(:wrap).in_sequence(s).with do |err, msg|
          err.message.should == 'fatal error'
          msg.should match(/Backup for test label \(test_trigger\) Failed!/)
        end.returns(error_a)
        Backup::Logger.expects(:error).in_sequence(s).with(error_a)
        Backup::Logger.expects(:error).in_sequence(s).with(
          "\nBacktrace:\n\s\smany\n\s\sbacktrace\n\s\slines\n\n"
        )

        Backup::Cleaner.expects(:warnings).in_sequence(s).with(model)

        Backup::Errors::ModelError.expects(:new).in_sequence(s).with do |msg|
          msg.should match(/Backup will now exit/)
        end.returns(error_b)
        Backup::Logger.expects(:error).in_sequence(s).with(error_b)

        expect do
          # notifiers called, but any Exception is ignored
          notifier = mock
          notifier.expects(:perform!).with(true).raises(Exception)
          model.expects(:notifiers).returns([notifier])
        end.not_to raise_error

        expect do
          model.perform!
        end.to raise_error(SystemExit) {|exit| exit.status.should be(1) }
      end

    end # context 'when errors occur'

  end # describe '#perform!'

  describe '#package!' do
    it 'should package the backup' do
      Backup::Packager.expects(:package!).in_sequence(s).with(model)
      Backup::Cleaner.expects(:remove_packaging).in_sequence(s).with(model)

      model.send(:package!)
      model.package.should be_an_instance_of Backup::Package
    end
  end

  describe '#clean' do
    it 'should remove the final packaged files' do
      package = mock
      model.instance_variable_set(:@package, package)
      Backup::Cleaner.expects(:remove_package).with(package)

      model.send(:clean!)
    end
  end

  describe '#procedures' do
    it 'should return an array of specific, ordered procedures' do
      model.stubs(:databases).returns(:databases)
      model.stubs(:archives).returns(:archives)
      model.stubs(:package!).returns(:package)
      model.stubs(:storages).returns(:storages)
      model.stubs(:clean!).returns(:clean)

      one, two, three, four, five = model.send(:procedures)
      one.should == :databases
      two.should == :archives
      three.call.should == :package
      four.should == :storages
      five.call.should == :clean
    end
  end

  describe '#procedure_instance_variables' do
    # these are all set to an empty Array in #initialize
    it 'should return an array of Array holding instance variables' do
      model.send(:procedure_instance_variables).should ==
          [:@databases, :@archives, :@storages, :@notifiers, :@syncers]
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

  describe '#log!' do
    context 'when action is :started' do
      it 'should log that the backup has started with the version' do
        Backup::Logger.expects(:message).with(
          "Performing Backup for 'test label (test_trigger)'!\n" +
          "[ backup #{ Backup::Version.current } : #{ RUBY_DESCRIPTION } ]"
        )
        model.send(:log!, :started)
      end
    end

    context 'when action is :finished' do
      before { model.expects(:elapsed_time).returns('01:02:03') }
      context 'when warnings were issued' do
        before { Backup::Logger.expects(:has_warnings?).returns(true) }
        it 'should log a warning that the backup has finished with warnings' do
          Backup::Logger.expects(:warn).with(
            "Backup for 'test label (test_trigger)' " +
            "Completed Successfully (with Warnings) in 01:02:03"
          )
          model.send(:log!, :finished)
        end
      end

      context 'when no warnings were issued' do
        it 'should log that the backup has finished with the elapsed time' do
          Backup::Logger.expects(:message).with(
            "Backup for 'test label (test_trigger)' " +
            "Completed Successfully in 01:02:03"
          )
          model.send(:log!, :finished)
        end
      end
    end
  end # describe '#log!'

  describe '#elapsed_time' do
    it 'should return a string representing the elapsed time' do
      Timecop.freeze(Time.now)
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
        model.instance_variable_set(:@started_at, Time.now - duration)
        model.send(:elapsed_time).should == expected
      end
    end
  end

end
