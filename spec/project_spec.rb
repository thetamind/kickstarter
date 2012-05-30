require 'webmock/rspec'
require 'kickstarter'

describe Kickstarter::Project do
  PROJECT_URL = "#{Kickstarter::BASE_URL}/projects/597507018/pebble-e-paper-watch"

  context "when in progress" do
    before(:each) do
      WebMock.enable!
      stub_request(:get, PROJECT_URL).
        to_return( File.new("./spec/project.txt").read )
    end

    subject { Kickstarter::Project.new(PROJECT_URL) }

    its(:video_poster_url) { should == "http://s3.amazonaws.com/ksr/projects/111694/photo-full.jpg?1334081632" }
    its(:video_url) { should == "http://s3.amazonaws.com/ksr/projects/111694/video-96723-h264_high.mp4" }
  end

  context "when finished" do
    before(:each) do
      WebMock.enable!
      stub_request(:get, PROJECT_URL).
        to_return( File.new("./spec/finished_project.txt").read )
    end

    subject { Kickstarter::Project.new(PROJECT_URL) }

    its(:video_poster_url) { should == "http://s3.amazonaws.com/ksr/projects/111694/photo-full.jpg?1334081632" }
    its(:video_url) { should == "http://s3.amazonaws.com/ksr/projects/111694/video-108947-h264_high.mp4" }
  end
end
