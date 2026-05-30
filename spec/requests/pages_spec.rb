require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /" do
    it "returns a successful response with the app name" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("all-aBoard")
    end
  end
end
