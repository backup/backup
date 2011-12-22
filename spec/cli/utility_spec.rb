# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::CLI::Utility' do
  let(:cli) { Backup::CLI::Utility }

  describe '#perform' do

    context 'when errors occur' do

      before do
        @argv_save = ARGV
      end

      after do
        ARGV.replace(@argv_save)
      end

      it 'should log the error and exit' do
        ARGV.replace(['perform', '-t', 'foo'])
        FileUtils.stubs(:mkdir_p).raises(SystemCallError, 'yikes!')

        Backup::Logger.expects(:error).with do |err|
          err.message.should ==
              "CLIError: SystemCallError: unknown error - yikes!"
        end

        expect do
          cli.start
        end.to raise_error(SystemExit)
      end

    end # context 'when errors occur'

  end # describe '#perform'

end
