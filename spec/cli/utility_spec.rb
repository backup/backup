# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::CLI::Utility' do
  let(:cli)     { Backup::CLI::Utility }
  let(:utility) { Backup::CLI::Utility.new }
  let(:s)       { sequence '' }

  before  { @argv_save = ARGV }
  after   { ARGV.replace(@argv_save) }

  describe '#perform' do
    let(:model_a) { Backup::Model.new(:test_trigger_a, 'test label a') }
    let(:model_b) { Backup::Model.new(:test_trigger_b, 'test label b') }

    after   { Backup::Model.all.clear }

    it 'should perform the backup for the given trigger' do
      Backup::Logger.expects(:quiet=).in_sequence(s)
      Backup::Config.expects(:update).in_sequence(s)

      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.log_path)
      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.cache_path)
      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.tmp_path)

      Backup::Config.expects(:load_config!).in_sequence(s)

      Backup::Logger.expects(:truncate!)

      model_a.expects(:prepare!).in_sequence(s)
      model_a.expects(:perform!).in_sequence(s)
      Backup::Logger.expects(:clear!).in_sequence(s)

      expect do
        ARGV.replace(['perform', '-t', 'test_trigger_a'])
        cli.start
      end.not_to raise_error
    end

    it 'should perform backups for the multiple triggers' do
      Backup::Logger.expects(:quiet=).in_sequence(s)
      Backup::Config.expects(:update).in_sequence(s)

      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.log_path)
      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.cache_path)
      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.tmp_path)

      Backup::Config.expects(:load_config!).in_sequence(s)

      Backup::Logger.expects(:truncate!)

      model_a.expects(:prepare!).in_sequence(s)
      model_a.expects(:perform!).in_sequence(s)
      Backup::Logger.expects(:clear!).in_sequence(s)

      model_b.expects(:prepare!).in_sequence(s)
      model_b.expects(:perform!).in_sequence(s)
      Backup::Logger.expects(:clear!).in_sequence(s)

      expect do
        ARGV.replace(['perform', '-t', 'test_trigger_a,test_trigger_b'])
        cli.start
      end.not_to raise_error
    end

    it 'should perform backups for the multiple triggers when using wildcard' do
      Backup::Logger.expects(:quiet=).in_sequence(s)
      Backup::Config.expects(:update).in_sequence(s)

      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.log_path)
      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.cache_path)
      FileUtils.expects(:mkdir_p).in_sequence(s).with(Backup::Config.tmp_path)

      Backup::Config.expects(:load_config!).in_sequence(s)

      Backup::Logger.expects(:truncate!)

      model_a.expects(:prepare!).in_sequence(s)
      model_a.expects(:perform!).in_sequence(s)
      Backup::Logger.expects(:clear!).in_sequence(s)

      model_b.expects(:prepare!).in_sequence(s)
      model_b.expects(:perform!).in_sequence(s)
      Backup::Logger.expects(:clear!).in_sequence(s)

      expect do
        ARGV.replace(['perform', '-t', 'test_trigger_*'])
        cli.start
      end.not_to raise_error
    end

    context 'when errors occur' do
      it 'should log the error and exit' do
        Backup::Logger.stubs(:quiet=).raises(SystemCallError, 'yikes!')
        Backup::Logger.expects(:error).with do |err|
          err.message.should ==
              "CLIError: SystemCallError: unknown error - yikes!"
        end

        expect do
          ARGV.replace(['perform', '-t', 'foo'])
          cli.start
        end.to raise_error(SystemExit) {|exit| exit.status.should == 1 }
      end
    end # context 'when errors occur'

  end # describe '#perform'

  describe '#generate:model' do
    before do
      FileUtils.unstub(:mkdir_p)
      FileUtils.unstub(:touch)
    end

    after do
      Backup::Config.send(:reset!)
    end

    context 'when given a config_path' do
      context 'when no config file exists' do
        it 'should create both a config and a model under the given path' do
          Dir.mktmpdir do |path|
            model_file  = File.join(path, 'custom', 'models', 'test_trigger.rb')
            config_file = File.join(path, 'custom', 'config.rb')

            out, err = capture_io do
              ARGV.replace(['generate:model',
                 '--config-path', File.join(path, 'custom'),
                 '--trigger', 'test_trigger'
              ])
              cli.start
            end

            out.should == "Generated model file: '#{ model_file }'.\n" +
                "Generated configuration file: '#{ config_file }'.\n"
            File.exist?(model_file).should be_true
            File.exist?(config_file).should be_true
          end
        end
      end

      context 'when a config file already exists' do
        it 'should only create a model under the given path' do
          Dir.mktmpdir do |path|
            model_file  = File.join(path, 'custom', 'models', 'test_trigger.rb')
            config_file = File.join(path, 'custom', 'config.rb')
            FileUtils.mkdir_p(File.join(path, 'custom'))
            FileUtils.touch(config_file)

            out, err = capture_io do
              ARGV.replace(['generate:model',
                 '--config-path', File.join(path, 'custom'),
                 '--trigger', 'test_trigger'
              ])
              cli.start
            end

            out.should == "Generated model file: '#{ model_file }'.\n"
            File.exist?(model_file).should be_true
          end
        end
      end

# These pass, but generate Thor warnings...
#
#      context 'when a model file already exists' do
#        it 'should prompt to overwrite the model under the given path' do
#          Dir.mktmpdir do |path|
#            model_file  = File.join(path, 'models', 'test_trigger.rb')
#            config_file = File.join(path, 'config.rb')
#
#            cli.any_instance.expects(:overwrite?).with(model_file).returns(false)
#
#            out, err = capture_io do
#              ARGV.replace(['generate:model',
#                 '--config-path', path,
#                 '--trigger', 'test_trigger'
#              ])
#              cli.start
#            end
#
#            out.should == "Generated configuration file: '#{ config_file }'.\n"
#            File.exist?(config_file).should be_true
#            File.exist?(model_file).should be_false
#          end
#        end
#      end

    end # context 'when given a config_path'

    context 'when not given a config_path' do
      it 'should create both a config and a model under the root path' do
        Dir.mktmpdir do |path|
          Backup::Config.update(:root_path => path)
          model_file  = File.join(path, 'models', 'test_trigger.rb')
          config_file = File.join(path, 'config.rb')

          out, err = capture_io do
            ARGV.replace(['generate:model', '--trigger', 'test_trigger'])
            cli.start
          end

          out.should == "Generated model file: '#{ model_file }'.\n" +
              "Generated configuration file: '#{ config_file }'.\n"
          File.exist?(model_file).should be_true
          File.exist?(config_file).should be_true
        end
      end
    end

    it 'should generate the proper help output' do
      ruby19_output = <<-EOS
        Usage:
          #{ File.basename($0) } generate:model --trigger=TRIGGER

        Options:
          --trigger=TRIGGER
          [--config-path=CONFIG_PATH]  # Path to your Backup configuration directory
          [--databases=DATABASES]      # (mongodb, mysql, postgresql, redis, riak)
          [--storages=STORAGES]        # (cloud_files, dropbox, ftp, local, ninefold, rsync, s3, scp, sftp)
          [--syncers=SYNCERS]          # (cloud_files, rsync_local, rsync_pull, rsync_push, s3)
          [--encryptors=ENCRYPTORS]    # (gpg, openssl)
          [--compressors=COMPRESSORS]  # (bzip2, custom, gzip, lzma, pbzip2)
          [--notifiers=NOTIFIERS]      # (campfire, hipchat, mail, prowl, pushover, twitter)
          [--archives]
          [--splitter]                 # use `--no-splitter` to disable
                                      # Default: true
        Generates a Backup model file

        Note:
          '--config-path' is the path to the directory where 'config.rb' is located.
          The model file will be created as '<config_path>/models/<trigger>.rb'
          Default: #{ Backup::Config.root_path }
      EOS

      out, err = capture_io do
        ARGV.replace(['help', 'generate:model'])
        cli.start
      end

      expected_lines = ruby19_output.split("\n").map(&:strip).select {|e| !e.empty? }
      output_lines = out.split("\n").map(&:strip).select {|e| !e.empty? }

      output_lines.sort.should == expected_lines.sort
    end
  end # describe '#generate:model'

  describe '#generate:config' do
    before do
      FileUtils.unstub(:mkdir_p)
      FileUtils.unstub(:touch)
    end

    after do
      Backup::Config.send(:reset!)
    end

    context 'when given a config_path' do
      it 'should create a config file in the given path' do
        Dir.mktmpdir do |path|
          config_file = File.join(path, 'custom', 'config.rb')

          out, err = capture_io do
            ARGV.replace(['generate:config',
                '--config-path', File.join(path, 'custom'),
            ])
            cli.start
          end

          out.should == "Generated configuration file: '#{ config_file }'.\n"
          File.exist?(config_file).should be_true
        end
      end
    end

    context 'when not given a config_path' do
      it 'should create a config file in the root path' do
        Dir.mktmpdir do |path|
          Backup::Config.update(:root_path => path)
          config_file = File.join(path, 'config.rb')

          out, err = capture_io do
            ARGV.replace(['generate:config'])
            cli.start
          end

          out.should == "Generated configuration file: '#{ config_file }'.\n"
          File.exist?(config_file).should be_true
        end
      end
    end

# These pass, but generate Thor warnings...
#
#    context 'when a config file already exists' do
#      it 'should prompt to overwrite the config file' do
#        Dir.mktmpdir do |path|
#          Backup::Config.update(:root_path => path)
#          config_file = File.join(path, 'config.rb')
#
#          cli.any_instance.expects(:overwrite?).with(config_file).returns(false)
#
#          out, err = capture_io do
#            ARGV.replace(['generate:config'])
#            cli.start
#          end
#
#          out.should be_empty
#          File.exist?(config_file).should be_false
#        end
#      end
#    end

  end # describe '#generate:config'

  describe '#decrypt' do

# These pass, but generate Thor warnings...
#
#    it 'should perform OpenSSL decryption' do
#      ARGV.replace(['decrypt', '--encryptor', 'openssl',
#                    '--in', 'in_file',
#                    '--out', 'out_file',
#                    '--base64', '--salt',
#                    '--password-file', 'pwd_file'])
#
#      cli.any_instance.expects(:`).with(
#        "openssl aes-256-cbc -d -base64 -pass file:pwd_file -salt " +
#        "-in 'in_file' -out 'out_file'"
#      )
#      cli.start
#    end
#
#    it 'should omit -pass option if no --password-file given' do
#      ARGV.replace(['decrypt', '--encryptor', 'openssl',
#                    '--in', 'in_file',
#                    '--out', 'out_file',
#                    '--base64', '--salt'])
#
#      cli.any_instance.expects(:`).with(
#        "openssl aes-256-cbc -d -base64  -salt " +
#        "-in 'in_file' -out 'out_file'"
#      )
#      cli.start
#    end
#
#    it 'should perform GnuPG decryption' do
#      ARGV.replace(['decrypt', '--encryptor', 'gpg',
#                    '--in', 'in_file',
#                    '--out', 'out_file'])
#
#      cli.any_instance.expects(:`).with(
#        "gpg -o 'out_file' -d 'in_file'"
#      )
#      cli.start
#    end

    it 'should show a message if given an invalid encryptor' do
      ARGV.replace(['decrypt', '--encryptor', 'foo',
                    '--in', 'in_file',
                    '--out', 'out_file'])
      out, err = capture_io do
        cli.start
      end
      err.should == ''
      out.should == "Unknown encryptor: foo\n" +
          "Use either 'openssl' or 'gpg'.\n"
    end
  end

#  would have the same Thor warnings issues...
#  describe '#dependencies' do
#  end

  describe '#version' do
    it 'should output the current version' do
      utility.expects(:puts).with("Backup #{ Backup::Version.current }")
      utility.version
    end

    it 'should output the current version for "-v"' do
      ARGV.replace ['-v']
      out, err = capture_io do
        cli.start
      end
      out.should == "Backup #{ Backup::Version.current }\n"
    end
  end

  describe '#overwrite?' do
    context 'when the path exists' do
      before { File.expects(:exist?).returns(true) }

      it 'should prompt user' do
        utility.expects(:yes?).with(
          "A file already exists at 'a/path'. Do you want to overwrite? [y/n]"
        ).returns(:response)
        utility.send(:overwrite?, 'a/path').should == :response
      end
    end

    context 'when the path does not exist' do
      before { File.expects(:exist?).returns(false) }
      it 'should return true' do
        utility.expects(:yes?).never
        utility.send(:overwrite?, 'a/path').should be_true
      end
    end
  end
end
