# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Storage::SCP',
    :if => Backup::SpecLive::CONFIG['storage']['scp']['specs_enabled'] do
  let(:trigger) { 'archive_scp' }

  def remote_files_for(storage, package)
    remote_path = storage.send(:remote_path_for, package)

    files = []
    storage.send(:transferred_files_for, package) do |local_file, remote_file|
      files << File.join(remote_path, remote_file)
    end
    files
  end

  def check_remote_for(storage, files)
    if (storage.username == Backup::Config.user) &&
        (storage.ip == 'localhost')
      files.each do |file|
        if !File.exist?(file)
          return false
        end
      end
      true
    else
      errors = []
      storage.send(:connection) do |ssh|
        files.each do |file|
          ssh.exec!("ls '#{file}'") do |ch, stream, data|
            errors << data if stream == :stderr
          end
        end
      end
      errors.empty?
    end
  end

  def clean_remote!(storage, package)
    return if (storage.username == Backup::Config.user) &&
        (storage.ip == 'localhost') &&
        (storage.path == Backup::SpecLive::TMP_PATH)

    remote_path = storage.send(:remote_path_for, package)
    h_safety_check(remote_path)
    storage.send(:connection) do |ssh|
      ssh.exec!("rm -r '#{remote_path}'")
    end
  end

  it 'should store the archive on the remote' do
    model = h_set_trigger(trigger)

    model.perform!

    storage = model.storages.first
    package = model.package
    files = remote_files_for(storage, package)
    files.count.should == 1

    check_remote_for(storage, files).should be_true

    clean_remote!(storage, package)
  end

  describe 'Storage::SCP Cycling' do
    context 'when archives exceed `keep` setting' do
      it 'should remove the oldest archive' do
        packages = []

        model = h_set_trigger(trigger)
        storage = model.storages.first
        model.perform!
        package = model.package
        package.filenames.count.should == 1
        packages << package
        sleep 1

        check_remote_for(
          storage, remote_files_for(storage, packages[0])
        ).should be_true

        model = h_set_trigger(trigger)
        storage = model.storages.first
        model.perform!
        package = model.package
        package.filenames.count.should == 1
        packages << package
        sleep 1

        check_remote_for(
          storage, remote_files_for(storage, packages[1])
        ).should be_true

        model = h_set_trigger(trigger)
        storage = model.storages.first
        model.perform!
        package = model.package
        package.filenames.count.should == 1
        packages << package

        check_remote_for(
          storage, remote_files_for(storage, packages[2])
        ).should be_true
        clean_remote!(storage, packages[2])

        check_remote_for(
          storage, remote_files_for(storage, packages[1])
        ).should be_true
        clean_remote!(storage, packages[1])

        check_remote_for(
          storage, remote_files_for(storage, packages[0])
        ).should be_false
      end
    end

    context 'when an archive to be removed does not exist' do
      it 'should log a warning and continue' do
        packages = []

        model = h_set_trigger(trigger)
        storage = model.storages.first
        model.perform!
        package = model.package
        package.filenames.count.should == 1
        packages << package
        sleep 1

        check_remote_for(
          storage, remote_files_for(storage, packages[0])
        ).should be_true

        model = h_set_trigger(trigger)
        storage = model.storages.first
        model.perform!
        package = model.package
        package.filenames.count.should == 1
        packages << package

        check_remote_for(
          storage, remote_files_for(storage, packages[1])
        ).should be_true

        # remove archive directory cycle! will attempt to remove

        if (storage.username == Backup::Config.user) &&
            (storage.ip == 'localhost')
          remote_path = storage.send(:remote_path_for, packages[0])
          h_safety_check(remote_path)
          FileUtils.rm_r(remote_path)
        else
          clean_remote!(storage, packages[0])
        end

        check_remote_for(
          storage, remote_files_for(storage, packages[0])
        ).should be_false

        check_remote_for(
          storage, remote_files_for(storage, packages[1])
        ).should be_true


        model = h_set_trigger(trigger)
        storage = model.storages.first
        expect do
          model.perform!
        end.not_to raise_error

        Backup::Logger.has_warnings?.should be_true

        package = model.package
        package.filenames.count.should == 1
        packages << package

        check_remote_for(
          storage, remote_files_for(storage, packages[1])
        ).should be_true
        clean_remote!(storage, packages[1])

        check_remote_for(
          storage, remote_files_for(storage, packages[2])
        ).should be_true
        clean_remote!(storage, packages[2])
      end
    end

  end # describe 'Storage::SCP Cycling'

end
