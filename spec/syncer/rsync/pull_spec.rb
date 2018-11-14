require "spec_helper"

module Backup
  describe Syncer::RSync::Pull do
    before do
      allow_any_instance_of(Syncer::RSync::Pull).to \
        receive(:utility).with(:rsync).and_return("rsync")
      allow_any_instance_of(Syncer::RSync::Pull).to \
        receive(:utility).with(:ssh).and_return("ssh")
    end

    describe "#perform!" do
      describe "pulling from the remote host" do
        specify "using :ssh mode" do
          syncer = Syncer::RSync::Pull.new do |s|
            s.mode = :ssh
            s.host = "my_host"
            s.path = "~/some/path/"
            s.directories do |dirs|
              dirs.add "/this/dir/"
              dirs.add "that/dir"
              dirs.add "~/home/dir/"
            end
          end

          expect(FileUtils).to receive(:mkdir_p).with(File.expand_path("~/some/path/"))

          expect(syncer).to receive(:run).with(
            "rsync --archive -e \"ssh -p 22\" " \
            "my_host:'/this/dir' :'that/dir' :'home/dir' " \
            "'#{File.expand_path("~/some/path/")}'"
          )
          syncer.perform!
        end

        specify "using :ssh_daemon mode" do
          syncer = Syncer::RSync::Pull.new do |s|
            s.mode = :ssh_daemon
            s.host = "my_host"
            s.path = "~/some/path/"
            s.directories do |dirs|
              dirs.add "/this/dir/"
              dirs.add "that/dir"
              dirs.add "~/home/dir/"
            end
          end

          expect(FileUtils).to receive(:mkdir_p).with(File.expand_path("~/some/path/"))

          expect(syncer).to receive(:run).with(
            "rsync --archive -e \"ssh -p 22\" " \
            "my_host::'/this/dir' ::'that/dir' ::'home/dir' " \
            "'#{File.expand_path("~/some/path/")}'"
          )
          syncer.perform!
        end

        specify "using :rsync_daemon mode" do
          syncer = Syncer::RSync::Pull.new do |s|
            s.mode = :rsync_daemon
            s.host = "my_host"
            s.path = "~/some/path/"
            s.directories do |dirs|
              dirs.add "/this/dir/"
              dirs.add "that/dir"
              dirs.add "~/home/dir/"
            end
          end

          expect(FileUtils).to receive(:mkdir_p).with(File.expand_path("~/some/path/"))

          expect(syncer).to receive(:run).with(
            "rsync --archive --port 873 " \
            "my_host::'/this/dir' ::'that/dir' ::'home/dir' " \
            "'#{File.expand_path("~/some/path/")}'"
          )
          syncer.perform!
        end
      end # describe 'pulling from the remote host'

      describe "password handling" do
        let(:s) { sequence "" }
        let(:syncer) { Syncer::RSync::Pull.new }

        it "writes and removes the temporary password file" do
          expect(syncer).to receive(:write_password_file!).ordered
          expect(syncer).to receive(:run).ordered
          expect(syncer).to receive(:remove_password_file!).ordered

          syncer.perform!
        end

        it "ensures temporary password file removal" do
          expect(syncer).to receive(:write_password_file!).ordered
          expect(syncer).to receive(:run).ordered.and_raise(VerySpecificError)
          expect(syncer).to receive(:remove_password_file!).ordered

          expect do
            syncer.perform!
          end.to raise_error(VerySpecificError)
        end
      end # describe 'password handling'

      describe "logging messages" do
        it "logs started/finished messages" do
          syncer = Syncer::RSync::Pull.new

          expect(Logger).to receive(:info).with("Syncer::RSync::Pull Started...")
          expect(Logger).to receive(:info).with("Syncer::RSync::Pull Finished!")
          syncer.perform!
        end

        it "logs messages using optional syncer_id" do
          syncer = Syncer::RSync::Pull.new("My Syncer")

          expect(Logger).to receive(:info).with("Syncer::RSync::Pull (My Syncer) Started...")
          expect(Logger).to receive(:info).with("Syncer::RSync::Pull (My Syncer) Finished!")
          syncer.perform!
        end
      end
    end # describe '#perform!'
  end
end
