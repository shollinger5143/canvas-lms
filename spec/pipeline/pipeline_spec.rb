require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'pipeline service' do
  let(:endpoint_instance) { double('endpoint instance', call: nil) }
  let(:endpoint) { double('endpoint class', new: endpoint_instance) }
  let(:http_client) { double('http_client', messages_post: nil) }

  before do
    allow(PipelineService::HTTPClient).to receive(:post)
    ENV['SYNCHRONOUS_PIPELINE_JOBS'] = 'true'
    @user = account_admin_user
    @course = Course.create!
    @enrollment = StudentEnrollment.new(valid_enrollment_attributes)
    @enrollment.course = @course
    @enrollment.save!

  end

  context "Missing configuration" do
    before do
      @original_pipeline_user = ENV['PIPELINE_USER_NAME']
      ENV['PIPELINE_USER_NAME'] = nil
    end

    after do
      ENV['PIPELINE_USER_NAME'] = @original_pipeline_user
    end

    it 'wont raise an error through the api cus its queued' do
      PipelineService.queue_mode = 'asynchronous'
      allow(PipelineService::HTTPClient).to receive(:post)

      expect { PipelineService.publish(@enrollment) }.to_not raise_error
    end

    it 'calling it directly will raise an error since its not queued' do
      expect { PipelineService::Commands::Publish.new(object: @enrollment).call }
        .to raise_error(RuntimeError, 'Missing config')
    end
  end

  context "Assignment" do
    let(:account_admin) { double('account admin') }
    let(:response) { double('response', parsed_response: {}) }
    let(:http_client_for_fetcher) { double('http_client_for_fetcher', get: response) }

    before do
      allow(PipelineService::Account).to receive(:account_admin).and_return(account_admin)
      allow(PipelineService::Serializers::Assignment).to receive(:http_client).and_return(http_client_for_fetcher)
      allow(PipelineService::Serializers::Assignment).to receive(:token).and_return('sometoken')

    end

    it 'posts to the http client' do
      expect(PipelineService::HTTPClient).to receive(:post)
      ::Assignment.create!(context: @course)
    end
  end

  context "Submission" do
    before do
      ENV['PIPELINE_ENDPOINT']  = 'https://example.com'
      ENV['PIPELINE_USER_NAME'] = 'example_user'
      ENV['PIPELINE_PASSWORD']  = 'example_password'
      ENV['CANVAS_DOMAIN']      = 'someschool.com'
    end

    it do
      expect(PipelineService::HTTPClient).to receive(:post)
      @enrollment.update(workflow_state: 'completed')
    end

    it 'will use the enrollment type with hashes' do
      # expect(PipelineService::HTTPClient).to receive(:post)
      expect(endpoint).to receive(:new).with(hash_including(object: @enrollment))
      PipelineService::Commands::Publish.new(
        object: { id: @enrollment.id },
        endpoint: endpoint
      ).call
    end
  end
end
