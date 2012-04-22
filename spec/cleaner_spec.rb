# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe 'Backup::Cleaner' do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:cleaner) { Backup::Cleaner }

  describe '#prepare' do
    let(:error_tail) do
      "  Please check the log for messages and/or your notifications\n" +
      "  concerning this backup: 'test label (test_trigger)'\n" +
      "  The temporary files which had to be removed should not have existed."
    end

    context 'when neither the tmp_path is dirty or package files exist' do
      it 'should do nothing' do
        cleaner.expects(:packaging_folder_dirty?).returns(false)
        cleaner.expects(:tmp_path_package_files).returns([])
        FileUtils.expects(:rm_rf).never
        FileUtils.expects(:rm_f).never
        Backup::Logger.expects(:warn).never

        cleaner.prepare(model)
      end
    end

    context 'when the tmp_path is dirty' do
      it 'should remove tmp_path and log a warning' do
        cleaner.expects(:packaging_folder_dirty?).returns(true)
        cleaner.expects(:tmp_path_package_files).returns([])
        FileUtils.expects(:rm_f).never

        FileUtils.expects(:rm_rf).with(
          File.join(Backup::Config.tmp_path, 'test_trigger')
        )
        Backup::Logger.expects(:warn).with do |err|
          err.should be_an_instance_of Backup::Errors::CleanerError
          err.message.should == "CleanerError: Cleanup Warning\n" +
            "  The temporary backup folder still contains files!\n" +
            "  '#{ File.join(Backup::Config.tmp_path, 'test_trigger') }'\n" +
            "  These files will now be removed.\n" +
            "  \n" + error_tail
        end

        cleaner.prepare(model)
      end
    end

    context 'when package files exist' do
      it 'should remove the files and log a warning' do
        cleaner.expects(:packaging_folder_dirty?).returns(false)
        cleaner.expects(:tmp_path_package_files).returns(['file1', 'file2'])
        FileUtils.expects(:rm_rf).never

        FileUtils.expects(:rm_f).with('file1')
        FileUtils.expects(:rm_f).with('file2')

        Backup::Logger.expects(:warn).with do |err|
          err.should be_an_instance_of Backup::Errors::CleanerError
          err.message.should == "CleanerError: Cleanup Warning\n" +
            "  The temporary backup folder '#{ Backup::Config.tmp_path }'\n" +
            "  appears to contain the package files from the previous backup!\n" +
            "  file1\n" +
            "  file2\n" +
            "  These files will now be removed.\n" +
            "  \n" + error_tail
        end

        cleaner.prepare(model)
      end
    end

    context 'both the tmp_path is dirty and package files exist' do
      it 'should clean both and log a warning' do
        cleaner.expects(:packaging_folder_dirty?).returns(true)
        cleaner.expects(:tmp_path_package_files).returns(['file1', 'file2'])

        FileUtils.expects(:rm_rf).with(
          File.join(Backup::Config.tmp_path, 'test_trigger')
        )
        FileUtils.expects(:rm_f).with('file1')
        FileUtils.expects(:rm_f).with('file2')

        Backup::Logger.expects(:warn).with do |err|
          err.should be_an_instance_of Backup::Errors::CleanerError
          err.message.should == "CleanerError: Cleanup Warning\n" +
            "  The temporary backup folder still contains files!\n" +
            "  '#{ File.join(Backup::Config.tmp_path, 'test_trigger') }'\n" +
            "  These files will now be removed.\n" +
            "  \n" +
            "  #{ '-' * 74 }\n" +
            "  The temporary backup folder '#{ Backup::Config.tmp_path }'\n" +
            "  appears to contain the package files from the previous backup!\n" +
            "  file1\n" +
            "  file2\n" +
            "  These files will now be removed.\n" +
            "  \n" + error_tail
        end

        cleaner.prepare(model)
      end
    end

  end # describe '#prepare'

  describe '#remove_packaging' do
    it 'should remove the packaging directory and log a message' do
      Backup::Logger.expects(:message).with(
        "Cleaning up the temporary files..."
      )
      FileUtils.expects(:rm_rf).with(
        File.join(Backup::Config.tmp_path, 'test_trigger')
      )

      cleaner.remove_packaging(model)
    end
  end

  describe '#remove_package' do
    let(:package) { mock }
    it 'should remove the files for the given package and log a message' do
      package.expects(:filenames).returns(['file1', 'file2'])
      Backup::Logger.expects(:message).with(
        "Cleaning up the package files..."
      )
      FileUtils.expects(:rm_f).with(
        File.join(Backup::Config.tmp_path, 'file1')
      )
      FileUtils.expects(:rm_f).with(
        File.join(Backup::Config.tmp_path, 'file2')
      )

      cleaner.remove_package(package)
    end
  end

  describe '#warnings' do
    let(:error_tail) do
      "  Make sure you check these files before the next scheduled backup for\n" +
      "  'test label (test_trigger)'\n" +
      "  These files will be removed at that time!"
    end

    context 'when neither the tmp_path is dirty or package files exist' do
      it 'should do nothing' do
        cleaner.expects(:packaging_folder_dirty?).returns(false)
        cleaner.expects(:tmp_path_package_files).returns([])
        Backup::Logger.expects(:warn).never

        cleaner.warnings(model)
      end
    end

    context 'when the tmp_path is dirty' do
      it 'should remove tmp_path and log a warning' do
        cleaner.expects(:packaging_folder_dirty?).returns(true)
        cleaner.expects(:tmp_path_package_files).returns([])

        Backup::Logger.expects(:warn).with do |err|
          err.should be_an_instance_of Backup::Errors::CleanerError
          err.message.should == "CleanerError: Cleanup Warning\n" +
            "  The temporary backup folder still contains files!\n" +
            "  '#{ File.join(Backup::Config.tmp_path, 'test_trigger') }'\n" +
            "  This folder may contain completed Archives and/or Database backups.\n" +
            "  \n" + error_tail
        end

        cleaner.warnings(model)
      end
    end

    context 'when package files exist' do
      it 'should remove the files and log a warning' do
        cleaner.expects(:packaging_folder_dirty?).returns(false)
        cleaner.expects(:tmp_path_package_files).returns(['file1', 'file2'])

        Backup::Logger.expects(:warn).with do |err|
          err.should be_an_instance_of Backup::Errors::CleanerError
          err.message.should == "CleanerError: Cleanup Warning\n" +
            "  The temporary backup folder '#{ Backup::Config.tmp_path }'\n" +
            "  appears to contain the backup files which were to be stored:\n" +
            "  file1\n" +
            "  file2\n" +
            "  \n" + error_tail
        end

        cleaner.warnings(model)
      end
    end

    context 'both the tmp_path is dirty and package files exist' do
      it 'should clean both and log a warning' do
        cleaner.expects(:packaging_folder_dirty?).returns(true)
        cleaner.expects(:tmp_path_package_files).returns(['file1', 'file2'])

        Backup::Logger.expects(:warn).with do |err|
          err.should be_an_instance_of Backup::Errors::CleanerError
          err.message.should == "CleanerError: Cleanup Warning\n" +
            "  The temporary backup folder still contains files!\n" +
            "  '#{ File.join(Backup::Config.tmp_path, 'test_trigger') }'\n" +
            "  This folder may contain completed Archives and/or Database backups.\n" +
            "  \n" +
            "  #{ '-' * 74 }\n" +
            "  The temporary backup folder '#{ Backup::Config.tmp_path }'\n" +
            "  appears to contain the backup files which were to be stored:\n" +
            "  file1\n" +
            "  file2\n" +
            "  \n" + error_tail
        end

        cleaner.warnings(model)
      end
    end

  end # describe '#warnings'

  describe '#packaging_folder_dirty?' do
    before do
      cleaner.instance_variable_set(:@model, model)
      FileUtils.unstub(:mkdir_p)
    end

    after do
      Backup::Config.send(:reset!)
    end

    context 'when files exist in the packaging folder' do
      it 'should return true' do
        Dir.mktmpdir do |path|
          Backup::Config.update(:root_path => path)
          FileUtils.mkdir_p(
            File.join(Backup::Config.tmp_path, 'test_trigger', 'archives')
          )
          cleaner.send(:packaging_folder_dirty?).should be_true
        end
      end
    end

    context 'when files do not exist in the packaging folder' do
      it 'should return false' do
        Dir.mktmpdir do |path|
          Backup::Config.update(:root_path => path)
          FileUtils.mkdir_p(
            File.join(Backup::Config.tmp_path, 'test_trigger')
          )
          cleaner.send(:packaging_folder_dirty?).should be_false
        end
      end
    end
  end

  describe '#tmp_path_package_files' do
    before do
      cleaner.instance_variable_set(:@model, model)
      FileUtils.unstub(:mkdir_p)
      FileUtils.unstub(:touch)
    end

    after do
      Backup::Config.send(:reset!)
    end

    context 'when packaging files exist in the tmp_path' do
      it 'should return the files' do
        Dir.mktmpdir do |path|
          Backup::Config.update(:root_path => path)
          FileUtils.mkdir_p(Backup::Config.tmp_path)

          package_files = [
            '2012.01.06.12.05.30.test_trigger.tar',
            '2012.02.06.12.05.30.test_trigger.tar-aa',
            '2012.03.06.12.05.30.test_trigger.tar.enc',
            '2012.04.06.12.05.30.test_trigger.tar.enc-aa'
          ].map! {|f| File.join(Backup::Config.tmp_path, f) }

          other_files = [
            '2012.01.06.12.05.30.test_trigger.target.tar',
            '2012.01.06.12.05.30.other_trigger.tar',
            'foo.tar'
          ].map! {|f| File.join(Backup::Config.tmp_path, f) }

          FileUtils.touch(package_files + other_files)
          Dir[File.join(Backup::Config.tmp_path, '*')].count.should be(7)

          cleaner.send(:tmp_path_package_files).sort.should == package_files
        end
      end
    end

    context 'when no packaging files exist in the tmp_path' do
      it 'should return an empty array' do
        Dir.mktmpdir do |path|
          Backup::Config.update(:root_path => path)
          FileUtils.mkdir_p(Backup::Config.tmp_path)

          other_files = [
            '2012.01.06.12.05.30.test_trigger.target.tar',
            '2012.01.06.12.05.30.other_trigger.tar',
            'foo.tar'
          ].map! {|f| File.join(Backup::Config.tmp_path, f) }

          FileUtils.touch(other_files)
          Dir[File.join(Backup::Config.tmp_path, '*')].count.should be(3)

          cleaner.send(:tmp_path_package_files).should == []
        end
      end
    end
  end

end
