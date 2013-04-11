# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Storage::Local' do
  let(:trigger) { 'archive_local' }

  def archive_file_for(model)
    File.join(
      Backup::SpecLive::TMP_PATH,
      "#{model.trigger}", model.time, "#{model.trigger}.tar"
    )
  end

  it 'should store a local archive' do
    model = h_set_trigger(trigger)
    model.perform!
    File.exist?(archive_file_for(model)).should be_true
  end

  describe 'Storage::Local Cycling' do

    context 'when archives exceed `keep` setting' do
      it 'should remove the oldest archive' do
        archives = []

        model = h_set_trigger(trigger)
        model.perform!
        archives << archive_file_for(model)
        sleep 1

        model = h_set_trigger(trigger)
        model.perform!
        archives << archive_file_for(model)
        sleep 1

        model = h_set_trigger(trigger)
        model.perform!
        archives << archive_file_for(model)

        File.exist?(archives[0]).should be_false
        File.exist?(archives[1]).should be_true
        File.exist?(archives[2]).should be_true
      end
    end

    context 'when an archive to be removed does not exist' do
      it 'should log a warning and continue' do
        archives = []

        model = h_set_trigger(trigger)
        model.perform!
        archives << archive_file_for(model)
        sleep 1

        model = h_set_trigger(trigger)
        model.perform!
        archives << archive_file_for(model)
        sleep 1

        File.exist?(archives[0]).should be_true
        File.exist?(archives[1]).should be_true
        # remove archive directory cycle! will attempt to remove
        dir = archives[0].split('/')[0...-1].join('/')
        h_safety_check(dir)
        FileUtils.rm_r(dir)
        File.exist?(archives[0]).should be_false

        expect do
          model = h_set_trigger(trigger)
          model.perform!
          archives << archive_file_for(model)
        end.not_to raise_error

        Backup::Logger.has_warnings?.should be_true

        File.exist?(archives[1]).should be_true
        File.exist?(archives[2]).should be_true
      end
    end

  end # describe 'Storage::Local Cycling'
end
