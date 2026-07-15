require "test_helper"

class DeploymentConfigTest < ActiveSupport::TestCase
  test "continuous integration uses sqlite without postgres" do
    workflow = Rails.root.join(".github/workflows/ci.yml").read

    assert_no_match(/postgres/i, workflow)
    assert_no_match(/DATABASE_URL/, workflow)
    assert_match(/bin\/rails db:prepare/, workflow)
    assert_match(/bin\/rails test/, workflow)
  end

  test "docker build context excludes local and persistent files" do
    dockerignore = Rails.root.join(".dockerignore").read

    %w[.env* storage/* .playwright-cli .serena].each do |entry|
      assert_includes dockerignore.lines.map(&:strip), entry
    end
  end

  test "production compose uses a separate project from development" do
    production_compose = Rails.root.join("compose.production.yaml").read

    assert_match(/\Aname: ink-ventory-production\n/, production_compose)
  end
end
