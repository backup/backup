# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Presently do

  describe '#initialize' do
    let(:notifier) do
      Backup::Notifier::Presently.new do |presently|
        presently.user_name = 'user_name'
        presently.subdomain = 'subdomain'
        presently.password  = 'password'
        presently.group_id  = 'group_id'
      end
    end

    it 'sets the correct defaults' do
      notifier.user_name.should == 'user_name'
      notifier.subdomain.should == 'subdomain'
      notifier.password.should  == 'password'
      notifier.group_id.should  == 'group_id'

      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    it 'uses and overrides configuration defaults' do
      Backup::Configuration::Notifier::Presently.defaults do |notifier|
        notifier.user_name  = 'old_user_name'
        notifier.on_success = false
        notifier.on_failure = true
      end
      presently = Backup::Notifier::Presently.new do |notifier|
        notifier.user_name = 'new_user_name'
      end

      presently.user_name.should  == 'new_user_name'
      presently.on_success.should == false
      presently.on_warning.should == true
      presently.on_failure.should == true
    end

    it 'creates a Presently::Client (using HTTParty)' do
      client = notifier.presently_client
      client.should be_an_instance_of Backup::Notifier::Presently::Client
      client.subdomain.should == notifier.subdomain
      client.user_name.should == notifier.user_name
      client.password.should == notifier.password
      client.group_id.should == notifier.group_id
      client.class.base_uri.
          should == "https://#{notifier.subdomain}.presently.com"
      client.class.default_options.should have_key(:basic_auth)
      client.class.default_options[:basic_auth][:username].
          should == notifier.user_name
      client.class.default_options[:basic_auth][:password].
          should == notifier.password
    end

  end # describe '#initialize'

  describe '#perform!' do
    let(:model) { Backup::Model.new('trigger', 'label') {} }
    let(:post_uri) { '/api/twitter/statuses/update.json' }
    let(:post_body) { { :status => nil, :source => 'Backup Notifier' } }
    let(:message) { '[Backup::%s] label (trigger)' }

    context 'with group_id' do
      let(:notifier) do
        Backup::Notifier::Presently.new do |presently|
          presently.user_name = 'user_name'
          presently.subdomain = 'subdomain'
          presently.password  = 'password'
          presently.group_id  = 'group_id'
        end
      end
      let(:client) { notifier.presently_client }

      before do
        notifier.on_success = false
        notifier.on_warning = false
        notifier.on_failure = false
      end

      context 'success' do

        context 'when on_success is true' do
          before { notifier.on_success = true }

          it 'sends success message' do
            notifier.expects(:log!)
            status = message % 'Success'
            client.class.expects(:post).with(
              post_uri, :body => post_body.merge(
                { :status => "d @#{notifier.group_id} %s" % status }
              )
            )

            notifier.perform!(model)
          end
        end

        context 'when on_success is false' do
          it 'sends no message' do
            notifier.expects(:log!).never
            notifier.expects(:notify!).never
            client.expects(:update).never

            notifier.perform!(model)
          end
        end

      end # context 'success'

      context 'warning' do
        before { Backup::Logger.stubs(:has_warnings?).returns(true) }

        context 'when on_success is true' do
          before { notifier.on_success = true }

          it 'sends warning message' do
            notifier.expects(:log!)
            status = message % 'Warning'
            client.class.expects(:post).with(
              post_uri, :body => post_body.merge(
                { :status => "d @#{notifier.group_id} %s" % status }
              )
            )

            notifier.perform!(model)
          end
        end

        context 'when on_warning is true' do
          before { notifier.on_warning = true }

          it 'sends warning message' do
            notifier.expects(:log!)
            status = message % 'Warning'
            client.class.expects(:post).with(
              post_uri, :body => post_body.merge(
                { :status => "d @#{notifier.group_id} %s" % status }
              )
            )

            notifier.perform!(model)
          end
        end

        context 'when on_success and on_warning are false' do
          it 'sends no message' do
            notifier.expects(:log!).never
            notifier.expects(:notify!).never
            client.expects(:update).never

            notifier.perform!(model)
          end
        end

      end # context 'warning'

      context 'failure' do

        context 'when on_failure is true' do
          before { notifier.on_failure = true }

          it 'sends failure message' do
            notifier.expects(:log!)
            status = message % 'Failure'
            client.class.expects(:post).with(
              post_uri, :body => post_body.merge(
                { :status => "d @#{notifier.group_id} %s" % status }
              )
            )

            notifier.perform!(model, Exception.new)
          end
        end

        context 'when on_failure is false' do
          it 'sends no message' do
            notifier.expects(:log!).never
            notifier.expects(:notify!).never
            client.expects(:update).never

            notifier.perform!(model, Exception.new)
          end
        end

      end # context 'failure'

    end # context 'with group_id'

    context 'without group_id' do
      let(:notifier) do
        Backup::Notifier::Presently.new do |presently|
          presently.user_name = 'user_name'
          presently.subdomain = 'subdomain'
          presently.password  = 'password'
          presently.group_id  = nil
        end
      end
      let(:client) { notifier.presently_client }

      before do
        notifier.on_success = false
        notifier.on_warning = false
        notifier.on_failure = false
      end

      context 'success' do

        context 'when on_success is true' do
          before { notifier.on_success = true }

          it 'sends success message' do
            notifier.expects(:log!)
            client.class.expects(:post).with(
              post_uri, :body => post_body.merge(
                { :status => message % 'Success' }
              )
            )

            notifier.perform!(model)
          end
        end

        context 'when on_success is false' do
          it 'sends no message' do
            notifier.expects(:log!).never
            notifier.expects(:notify!).never
            client.expects(:update).never

            notifier.perform!(model)
          end
        end

      end # context 'success'

      context 'warning' do
        before { Backup::Logger.stubs(:has_warnings?).returns(true) }

        context 'when on_success is true' do
          before { notifier.on_success = true }

          it 'sends warning message' do
            notifier.expects(:log!)
            client.class.expects(:post).with(
              post_uri, :body => post_body.merge(
                { :status => message % 'Warning' }
              )
            )

            notifier.perform!(model)
          end
        end

        context 'when on_warning is true' do
          before { notifier.on_warning = true }

          it 'sends warning message' do
            notifier.expects(:log!)
            client.class.expects(:post).with(
              post_uri, :body => post_body.merge(
                { :status => message % 'Warning' }
              )
            )

            notifier.perform!(model)
          end
        end

        context 'when on_success and on_warning are false' do
          it 'sends no message' do
            notifier.expects(:log!).never
            notifier.expects(:notify!).never
            client.expects(:update).never

            notifier.perform!(model)
          end
        end

      end # context 'warning'

      context 'failure' do

        context 'when on_failure is true' do
          before { notifier.on_failure = true }

          it 'sends failure message' do
            notifier.expects(:log!)
            client.class.expects(:post).with(
              post_uri, :body => post_body.merge(
                { :status => message % 'Failure' }
              )
            )

            notifier.perform!(model, Exception.new)
          end
        end

        context 'when on_failure is false' do
          it 'sends no message' do
            notifier.expects(:log!).never
            notifier.expects(:notify!).never
            client.expects(:update).never

            notifier.perform!(model, Exception.new)
          end
        end

      end # context 'failure'

    end # context 'without group_id'
  end # describe '#perform!'
end
