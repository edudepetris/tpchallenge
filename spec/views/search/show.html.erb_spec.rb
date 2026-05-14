require "rails_helper"

RSpec.describe "search/show.html.erb", type: :view do
  before { render }

  let(:form) { Capybara.string(rendered).find("form.search__form") }

  it "POSTs to the search path" do
    expect(form[:action]).to eq(search_path)
    expect(form[:method]).to eq("post")
  end

  it "is Turbo-enabled so submissions negotiate text/vnd.turbo-stream.html" do
    expect(form["data-turbo"]).not_to eq("false")
    expect(form["data-remote"]).to be_nil
  end

  it "submits the query under the :q param" do
    expect(form).to have_css("input[type='search'][name='q']")
  end
end
