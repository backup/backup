# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Storage::Dropbox',
    :if => Backup::SpecLive::CONFIG['storage']['dropbox']['specs_enabled'] do
  let(:trigger) { 'archive_dropbox' }

  def remote_files_for(storage, package)
    remote_path = storage.send(:remote_path_for, package)

    files = []
    storage.send(:transferred_files_for, package) do |local_file, remote_file|
      files << File.join(remote_path, remote_file)
    end
    files
  end

  def check_remote_for(storage, package, expectation = true)
    remote_path = storage.send(:remote_path_for, package)

    # search the remote_path folder for the trigger (base file name)
    metadata = storage.send(:connection).search(
      remote_path, package.trigger
    )
    files_found = metadata.map {|entry| File.basename(entry['path']) }

    files = remote_files_for(storage, package).map {|file| File.basename(file) }

    if expectation
      files_found.sort.should == files.sort
    else
      files_found.should be_empty
    end
  end

  def clean_remote!(storage, package)
    storage.send(:remove!, package)
  end

  it 'should store the archive on the remote', :init => true do
    model = h_set_trigger(trigger)

    model.perform!

    storage = model.storages.first
    package = model.package
    files = remote_files_for(storage, package)
    files.count.should == 1

    check_remote_for(storage, package)

    clean_remote!(storage, package)
  end

  describe 'Storage::Dropbox Cycling' do
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

        check_remote_for(storage, packages[0])

        model = h_set_trigger(trigger)
        storage = model.storages.first
        model.perform!
        package = model.package
        package.filenames.count.should == 1
        packages << package
        sleep 1

        check_remote_for(storage, packages[1])

        model = h_set_trigger(trigger)
        storage = model.storages.first
        model.perform!
        package = model.package
        package.filenames.count.should == 1
        packages << package

        check_remote_for(storage, packages[2])
        clean_remote!(storage, packages[2])

        check_remote_for(storage, packages[1])
        clean_remote!(storage, packages[1])

        check_remote_for(storage, packages[0], false)
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

        check_remote_for(storage, packages[0])

        model = h_set_trigger(trigger)
        storage = model.storages.first
        model.perform!
        package = model.package
        package.filenames.count.should == 1
        packages << package

        check_remote_for(storage, packages[1])

        # remove archive directory cycle! will attempt to remove
        clean_remote!(storage, packages[0])

        check_remote_for(storage, packages[0], false)

        check_remote_for(storage, packages[1])


        model = h_set_trigger(trigger)
        storage = model.storages.first
        expect do
          model.perform!
        end.not_to raise_error

        Backup::Logger.has_warnings?.should be_true

        package = model.package
        package.filenames.count.should == 1
        packages << package

        check_remote_for(storage, packages[1])
        clean_remote!(storage, packages[1])

        check_remote_for(storage, packages[2])
        clean_remote!(storage, packages[2])
      end
    end

  end # describe 'Storage::SCP Cycling'

end
