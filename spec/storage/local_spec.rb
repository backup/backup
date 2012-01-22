# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Local do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage_path) do
    File.join(File.expand_path(ENV['HOME'] || ''), 'backups')
  end
  let(:storage) do
    Backup::Storage::Local.new(model) do |local|
      local.keep = 5
    end
  end

  describe '#initialize' do
    it 'should set the correct values' do
      storage.path.should == storage_path

      storage.storage_id.should be_nil
      storage.keep.should       == 5
    end

    it 'should set a storage_id if given' do
      local = Backup::Storage::Local.new(model, 'my storage_id')
      local.storage_id.should == 'my storage_id'
    end

    it 'should expand any path given' do
      storage = Backup::Storage::Local.new(model) do |local|
        local.path = 'my_backups/path'
      end
      storage.path.should == File.expand_path('my_backups/path')
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Storage::Local.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Storage::Local.defaults do |local|
          local.path = 'some_path'
          local.keep = 'some_keep'
        end
        storage = Backup::Storage::Local.new(model)
        storage.path.should == File.expand_path('some_path')

        storage.storage_id.should be_nil
        storage.keep.should       == 'some_keep'
      end

      it 'should override the configured defaults' do
        Backup::Configuration::Storage::Local.defaults do |local|
          local.path = 'old_path'
          local.keep = 'old_keep'
        end
        storage = Backup::Storage::Local.new(model) do |local|
          local.path = 'new_path'
          local.keep = 'new_keep'
        end

        storage.path.should == File.expand_path('new_path')

        storage.storage_id.should be_nil
        storage.keep.should       == 'new_keep'
      end
    end # context 'when setting configuration defaults'

  end # describe '#initialize'

  describe '#transfer!' do
    let(:package) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::Local')
      storage.stubs(:local_path).returns('/local/path')
    end

    context 'when transfer_method is :mv' do
      before { storage.stubs(:transfer_method).returns(:mv) }
      it 'should move the package files to their destination' do
        storage.expects(:remote_path_for).in_sequence(s).with(package).
            returns('remote/path')
        FileUtils.expects(:mkdir_p).in_sequence(s).with('remote/path')

        storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
          multiple_yields(
          ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
          ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
        )
        # first yield
        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::Local started transferring " +
          "'2011.12.31.11.00.02.backup.tar.enc-aa'."
        )
        FileUtils.expects(:mv).in_sequence(s).with(
          File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'),
          File.join('remote/path', 'backup.tar.enc-aa')
        )
        # second yield
        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::Local started transferring " +
          "'2011.12.31.11.00.02.backup.tar.enc-ab'."
        )
        FileUtils.expects(:mv).in_sequence(s).with(
          File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'),
          File.join('remote/path', 'backup.tar.enc-ab')
        )

        storage.send(:transfer!)
      end
    end # context 'when transfer_method is :mv'

    context 'when transfer_method is :cp' do
      before { storage.stubs(:transfer_method).returns(:cp) }
      it 'should copy the package files to their destination' do
        storage.expects(:remote_path_for).in_sequence(s).with(package).
            returns('remote/path')
        FileUtils.expects(:mkdir_p).in_sequence(s).with('remote/path')

        storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
          multiple_yields(
          ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
          ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
        )
        # first yield
        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::Local started transferring " +
          "'2011.12.31.11.00.02.backup.tar.enc-aa'."
        )
        FileUtils.expects(:cp).in_sequence(s).with(
          File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'),
          File.join('remote/path', 'backup.tar.enc-aa')
        )
        # second yield
        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::Local started transferring " +
          "'2011.12.31.11.00.02.backup.tar.enc-ab'."
        )
        FileUtils.expects(:cp).in_sequence(s).with(
          File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'),
          File.join('remote/path', 'backup.tar.enc-ab')
        )

        storage.send(:transfer!)
      end
    end # context 'when transfer_method is :cp'

  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::Local')
    end

    it 'should remove the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')

      storage.expects(:transferred_files_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # after both yields
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Local started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa'.\n" +
        "Storage::Local started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab'."
      )
      FileUtils.expects(:rm_r).in_sequence(s).with('remote/path')

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

  describe '#transfer_method' do
    context 'when the storage is the last for the model' do
      before do
        model.storages << storage
      end

      it 'should return :mv' do
        storage.send(:transfer_method).should == :mv
        storage.instance_variable_get(:@transfer_method).should == :mv
      end

      it 'should only check once' do
        storage.instance_variable_set(:@transfer_method, :mv)
        model.expects(:storages).never
        storage.send(:transfer_method).should == :mv
      end
    end # context 'when the storage is the last for the model'

    context 'when the storage is not the last for the model' do
      let(:package) { mock }

      before do
        model.storages << storage
        model.storages << Backup::Storage::Local.new(model)

        storage.instance_variable_set(:@package, package)
      end

      it 'should log a warning and return :cp' do
        storage.expects(:remote_path_for).with(package).returns('remote_path')
        Backup::Logger.expects(:warn).with do |err|
          err.should be_an_instance_of Backup::Errors::Storage::Local::TransferError
          err.message.should ==
            "Storage::Local::TransferError: Local File Copy Warning!\n" +
            "  The final backup file(s) for 'test label' (test_trigger)\n" +
            "  will be *copied* to 'remote_path'\n" +
            "  To avoid this, when using more than one Storage, the 'Local' Storage\n" +
            "  should be added *last* so the files may be *moved* to their destination."
        end

        storage.send(:transfer_method).should == :cp
        storage.instance_variable_get(:@transfer_method).should == :cp
      end

      it 'should only check once' do
        storage.instance_variable_set(:@transfer_method, :cp)
        model.expects(:storages).never
        storage.send(:transfer_method).should == :cp
      end
    end # context 'when the storage is not the last for the model'

  end # describe '#transfer_method'

end
